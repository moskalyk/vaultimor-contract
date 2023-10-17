// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vaultimor, ERC1271} from "../src/Vaultimor.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MyERC1155 is ERC1155 {
    constructor() ERC1155("https://example.com/token/{id}.json") {}

    function mintTo(address to, uint256 tokenId, uint256 amount) external {
        _mint(to, tokenId, amount, "");
    }
}

contract Recipient is ERC1271 {
    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4) {
        // All calls are valid
        return 0x1626ba7e;
    }
}

contract VaultimoreTest is Test {
    Vaultimor private vaultimor;
    MyERC1155 private token;

    address private user = address(0x1234567890123456789012345678901234567890);
    Recipient private receipient = new Recipient();

    function setUp() public {
        vm.label(user, "user");

        vaultimor = new Vaultimor();

        token = new MyERC1155();
        token.mintTo(user, 0, 10);

        vm.prank(user);
        token.setApprovalForAll(address(vaultimor), true);
    }

    function testVault() public {
        vaultimor.create(user, address(token), 0, address(receipient), 100, "", 10);

        vaultimor.vaults(0);
    }
}
