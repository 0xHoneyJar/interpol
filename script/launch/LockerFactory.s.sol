// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LockerFactory} from "src/LockerFactory.sol";
import {HoneyLocker} from "src/HoneyLocker.sol";
import {Config} from "./Config.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract LockerFactoryDeploy is Script {
    using stdJson for string;

    LockerFactory public factory;

    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();

        address honeyQueen = json.readAddress("$.honeyqueen");
        address owner = json.readAddress("$.owner");
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        
        vm.startBroadcast(pkey);

        address lockerBeacon = Upgrades.deployBeacon("HoneyLocker.sol:HoneyLocker", owner);
        //address lockerImplementation = address(new HoneyLocker());
        //address lockerBeacon = address(new UpgradeableBeacon(lockerImplementation, owner));
        
        factory = new LockerFactory(honeyQueen, pubkey);
        factory.setBeacon(lockerBeacon);

        vm.stopBroadcast();

        vm.writeJson(
            vm.toString(address(factory)),
            config.getConfigFilename(),
            ".lockerFactory"
        );
        vm.writeJson(
            vm.toString(address(lockerBeacon)),
            config.getConfigFilename(),
            ".lockerBeacon"
        );

        console.log("LockerFactory deployed at", address(factory));
        console.log("LockerBeacon deployed at", address(lockerBeacon));
    }

    function getLockerFactory() public view returns (LockerFactory) {
        return factory;
    }
}
