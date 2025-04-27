// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {HoneyQueenV3} from "../src/HoneyQueenV3.sol";
import {HoneyLockerV3} from "../src/HoneyLockerV3.sol";

contract UpdateScript is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pkey);

        // // deploy new implementations for honeyqueen
        Options memory honeyQueenOpts;
        honeyQueenOpts.referenceContract = "HoneyQueenV2.sol:HoneyQueenV2";
        Upgrades.upgradeProxy(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B, "HoneyQueenV3.sol:HoneyQueenV3", "", honeyQueenOpts);
        HoneyQueenV3 honeyQueen = HoneyQueenV3(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B);
        honeyQueen.setBGM(0x488F847E277D6cC50EB349c493aa0875136cBFF1);

        

        // // upgrade honeylocker
        Options memory lockerBeaconOpts;
        lockerBeaconOpts.referenceContract = "HoneyLockerV2.sol:HoneyLockerV2";
        address honeyLockerV3 = Upgrades.deployImplementation("HoneyLockerV3.sol:HoneyLockerV3", lockerBeaconOpts);
        console.log("HoneyLockerV3 deployed at:", honeyLockerV3);

        // // upgrade BGTStationAdapter beacon
        Options memory adapterBeaconOpts;
        adapterBeaconOpts.referenceContract = "BGTStationAdapter.sol:BGTStationAdapter";
        address bgtStationAdapterV2 = Upgrades.deployImplementation("BGTStationAdapterV2.sol:BGTStationAdapterV2", adapterBeaconOpts);
        console.log("BGTStationAdapterV2 deployed at:", bgtStationAdapterV2);

        vm.stopBroadcast();
    }
}
