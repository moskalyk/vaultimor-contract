// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

interface ERC1271 {
    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4);
}

contract Vaultimor is IERC1155Receiver {

    bytes4 constant internal MAGICVALUE = 0x1626ba7e;

    struct Vault {
        uint time;
        uint256 tokenID;
        uint256 amount;  // NEW: amount for ERC-1155 tokens
        address sender;
        address recipient;
        address contractAddress;
    }

    Vault[] public vaults;
    address[] public mods;

    constructor() {
        mods.push(msg.sender);
    }

    modifier onlyMod() {
        require(isMod(msg.sender), "Not a mod");
        _;
    }

    function isMod(address _address) internal view returns (bool) {
        for (uint i = 0; i < mods.length; i++) {
            if (mods[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function addToModList(address _mod) external onlyMod {
        // Optional: Check if the address is already a mod to prevent duplicates
        require(!isMod(_mod), "Address is already a mod");

        mods.push(_mod);
    }

    // create a message, sign a transaction, store offchain
    // verify that the details are correct onchain as delegate
    function create(address _vaulter, address _contractAddress, uint _tokenID, address _recipient, uint _time, bytes calldata signature_, uint _amount) onlyMod external {

        bytes memory data = abi.encodePacked(keccak256(abi.encodePacked(_vaulter, _contractAddress, _tokenID, _recipient, _time)));
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 _hash = keccak256(abi.encodePacked(prefix, data));
        bytes4 result = ERC1271(_recipient).isValidSignature(_hash, signature_);

        require(result == MAGICVALUE, "INVALID_SIGNATURE");
        // num = _time;

        IERC1155(_contractAddress).safeTransferFrom(_vaulter, address(this), _tokenID, _amount, "");

        Vault memory newVault = Vault({
            time: _time,
            tokenID: _tokenID,
            amount: _amount,  // Store the amount
            sender: _vaulter,
            recipient: _recipient,
            contractAddress: _contractAddress
        });
        
        vaults.push(newVault);
    }

    function unlock(address _contractAddress, uint256 _tokenID) external {
        uint i = 0;
        while (i < vaults.length) {
            Vault storage vault = vaults[i];

            if (block.timestamp >= vault.time && vault.contractAddress == _contractAddress && vault.tokenID == _tokenID) {
                IERC1155(vault.contractAddress).safeTransferFrom(address(this), vault.recipient, vault.tokenID, vault.amount, "");

                vaults[i] = vaults[vaults.length - 1];
                vaults.pop();
            } else {
                i++;
            }
        }
    }

    function getVault(uint index) external view returns (Vault memory) {
        return vaults[index];
    }

    function retrieve(address _contractAddress, uint _tokenID, uint _amount) external {
        IERC1155(_contractAddress).safeTransferFrom(address(this), msg.sender, _tokenID, _amount, "");
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
