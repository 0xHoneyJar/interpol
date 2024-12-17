// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {AdapterFactory} from "../src/AdapterFactory.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Config} from "./Config.sol";

contract AdapterFactoryDeploy is Script {
    using stdJson for string;

    AdapterFactory public factory;
    
    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        address honeyQueen = json.readAddress("$.honeyqueen");
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        factory = new AdapterFactory(honeyQueen);
        vm.stopBroadcast();

        vm.writeJson(
            vm.toString(address(factory)),
            config.getConfigFilename(),
            ".adapterFactory"
        );
    }

    function getAdapterFactory() public view returns (AdapterFactory) {
        return factory;
    }
}
