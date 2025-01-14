// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Beekeeper} from "../src/Beekeeper.sol";
import {Config} from "./Config.sol";

contract BeekeeperDeploy is Script {
    using stdJson for string;

    Beekeeper public beekeeper;

    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        address treasury = json.readAddress("$.treasury");

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        
        beekeeper = new Beekeeper(pubkey, treasury);

        vm.stopBroadcast();

        vm.writeJson(vm.toString(address(beekeeper)), config.getConfigFilename(), ".beekeeper");
        console.log("Beekeeper deployed at", address(beekeeper));
    }

    function getBeekeeper() public view returns (Beekeeper) {
        return beekeeper;
    }
}
