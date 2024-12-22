// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Config} from "./Config.sol";

contract HoneyQueenDeploy is Script {
    using stdJson for string;

    HoneyQueen public queen;

    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        address BGT = json.readAddress("$.BGT");

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        queen = new HoneyQueen(BGT, address(0)); // Temporary zero address
        vm.stopBroadcast();

        vm.writeJson(vm.toString(address(queen)), config.getConfigFilename(), ".honeyqueen");
        console.log("HoneyQueen deployed at", address(queen));
    }

    function getHoneyQueen() public view returns (HoneyQueen) {
        return queen;
    }
}
