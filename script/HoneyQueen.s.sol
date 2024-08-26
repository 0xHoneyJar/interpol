// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";

contract HoneyQueenDeploy is Script {
    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        address BGT = 0xbDa130737BDd9618301681329bF2e46A016ff9Ad;
        HoneyQueen hq = new HoneyQueen(pubkey, BGT, address(0));
        vm.stopBroadcast();
    }
}
