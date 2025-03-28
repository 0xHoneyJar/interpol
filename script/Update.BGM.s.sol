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
        HoneyQueenV3 honeyQueenV3 = new HoneyQueenV3();
        HoneyQueenV3 honeyQueen = HoneyQueenV3(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B);
        honeyQueen.upgradeToAndCall(address(honeyQueenV3), "");
        honeyQueen.setBGM(0x488F847E277D6cC50EB349c493aa0875136cBFF1);

        // // upgrade honeylocker
        Options memory lockerBeaconOpts;
        lockerBeaconOpts.referenceContract = "HoneyLockerV2.sol:HoneyLockerV2";
        Upgrades.upgradeBeacon(0xD57848B26aBed18E36Fdb368E45F081C3A8C9980, "HoneyLockerV3.sol:HoneyLockerV3", lockerBeaconOpts);

        // // upgrade BGTStationAdapter beacon
        Options memory adapterBeaconOpts;
        adapterBeaconOpts.referenceContract = "BGTStationAdapter.sol:BGTStationAdapter";
        Upgrades.upgradeBeacon(0x6571d9e2830ab0d500ffe557e94EA45762Fd8B8f, "BGTStationAdapterV2.sol:BGTStationAdapterV2", adapterBeaconOpts);

        vm.stopBroadcast();
    }
}
