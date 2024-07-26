// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryDeploy is Script {
    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        address honeyQueen = 0x0f5087d74e3A9d5304b6A6e31668BD7761334c3c;
        vm.startBroadcast(pkey);
        Factory factory = new Factory(honeyQueen);
        vm.stopBroadcast();
    }
}
