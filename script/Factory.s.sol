// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryDeploy is Script {
    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        address honeyQueen = 0x8FbDFf12B0027443a297564A017f794a5f91EE29;
        vm.startBroadcast(pkey);
        Factory factory = new Factory(honeyQueen);
        vm.stopBroadcast();
    }
}
