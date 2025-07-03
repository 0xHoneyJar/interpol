// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {HoneyQueenV4} from "../src/HoneyQueenV4.sol";
import {HoneyLockerV4} from "../src/HoneyLockerV4.sol";

//   HoneyLockerV4 deployed at: 0x3e72b3f266E8C0C46EB65C4a5B2B15b8789F12D8
//   BGTStationAdapterV3 deployed at: 0x9FFdCBB531Ac15030E42a173Bc831403891Ae9e5

contract Update is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pkey);

        // // deploy new implementations for honeyqueen
        Options memory honeyQueenOpts;
        honeyQueenOpts.referenceContract = "HoneyQueenV3.sol:HoneyQueenV3";
        Upgrades.upgradeProxy(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B, "HoneyQueenV4.sol:HoneyQueenV4", "", honeyQueenOpts);
        HoneyQueenV4 honeyQueen = HoneyQueenV4(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B);
        honeyQueen.setInfrared(0xb71b3DaEA39012Fb0f2B14D2a9C86da9292fC126);
        honeyQueen.setInfraredBGT(0xac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b);

        honeyQueen.transferOwnership(0xd6C0E5F5F201f95F660bB7CFbb214Bd81dd4AB87);

        

        // // upgrade honeylocker
        Options memory lockerBeaconOpts;
        lockerBeaconOpts.referenceContract = "HoneyLockerV3.sol:HoneyLockerV3";
        address honeyLockerV4 = Upgrades.deployImplementation("HoneyLockerV4.sol:HoneyLockerV4", lockerBeaconOpts);
        console.log("HoneyLockerV4 deployed at:", honeyLockerV4);

        // // upgrade BGTStationAdapter beacon
        Options memory adapterBeaconOpts;
        adapterBeaconOpts.referenceContract = "BGTStationAdapterV2.sol:BGTStationAdapterV2";
        address bgtStationAdapterV3 = Upgrades.deployImplementation("BGTStationAdapterV3.sol:BGTStationAdapterV3", adapterBeaconOpts);
        console.log("BGTStationAdapterV3 deployed at:", bgtStationAdapterV3);

        vm.stopBroadcast();
    }
}
