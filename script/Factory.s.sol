// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryDeploy is Script {
    using stdJson for string;
    function setUp() public {}

    function run() public {
        string memory json = vm.readFile("./script/config.json");
        address honeyQueen = json.readAddress("$.honeyqueen");
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        Factory factory = new Factory(honeyQueen);
        vm.stopBroadcast();

        vm.writeJson(vm.toString(address(factory)), "./script/config.json", ".factory");
    }
}
