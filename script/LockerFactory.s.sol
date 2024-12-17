// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {LockerFactory} from "../src/LockerFactory.sol";
import {Config} from "./Config.sol";

contract LockerFactoryDeploy is Script {
    using stdJson for string;

    LockerFactory public factory;

    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        address honeyQueen = json.readAddress("$.honeyqueen");
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);
        factory = new LockerFactory(honeyQueen);
        vm.stopBroadcast();

        vm.writeJson(
            vm.toString(address(factory)),
            config.getConfigFilename(),
            ".lockerFactory"
        );
    }

    function getLockerFactory() public view returns (LockerFactory) {
        return factory;
    }
}
