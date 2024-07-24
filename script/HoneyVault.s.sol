// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HoneyVault} from "../src/HoneyVault.sol";

contract HoneyVaultDeploy is Script {
    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        HoneyVault vault = new HoneyVault();
        vm.stopBroadcast();
    }
}
