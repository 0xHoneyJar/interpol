// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Beekeeper} from "../src/Beekeeper.sol";

contract BeekeeperDeploy is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        string memory json = vm.readFile("./script/config.json");
        address treasury = json.readAddress("$.treasury");

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        Beekeeper bk = new Beekeeper(pubkey, treasury);
        vm.stopBroadcast();

        vm.writeJson(vm.toString(address(bk)), "./script/config.json", ".beekeeper");
    }
}
