// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyQueenV3} from "../src/HoneyQueenV3.sol";

contract UpdateTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    address lockerBeacon            = 0xD57848B26aBed18E36Fdb368E45F081C3A8C9980;
    address honeyQueenProxy         = 0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B;

    address honeyQueenOwner         = 0xDe81B20B6801d99EFEaEcEd48a11ba025180b8cc;
    address lockerBeaconOwner       = 0xd6C0E5F5F201f95F660bB7CFbb214Bd81dd4AB87;

    address bgmProxy                = 0x488F847E277D6cC50EB349c493aa0875136cBFF1;
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL_MAINNET);

        vm.stopPrank();
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    function test_mainnet_update() public {
        // first upgrade HQ
        vm.startPrank(honeyQueenOwner);
        Options memory honeyQueenOpts;
        honeyQueenOpts.referenceContract = "HoneyQueen.sol:HoneyQueen";
        Upgrades.upgradeProxy(honeyQueenProxy, "HoneyQueenV2.sol:HoneyQueenV2", "", honeyQueenOpts);
        vm.stopPrank();

        // then upgrade locker beacon
        vm.startPrank(lockerBeaconOwner);
        Options memory lockerBeaconOpts;
        lockerBeaconOpts.referenceContract = "HoneyLocker.sol:HoneyLocker";
        Upgrades.upgradeBeacon(lockerBeacon, "HoneyLockerV2.sol:HoneyLockerV2", lockerBeaconOpts);
        vm.stopPrank();

    }

    function test_mainnet_v3_update() public {
        // first upgrade HQ
        vm.startPrank(honeyQueenOwner);
        HoneyQueenV3 newImpl = new HoneyQueenV3();
        HoneyQueenV3 honeyQueen = HoneyQueenV3(honeyQueenProxy);

        address beekeeper = honeyQueen.beekeeper();

        honeyQueen.upgradeToAndCall(address(newImpl), "");
        honeyQueen.setBGM(bgmProxy);

        assertEq(honeyQueen.beekeeper(), beekeeper);
        assertEq(honeyQueen.BGM(), bgmProxy);

        vm.stopPrank();

        // upgrade locker beacon
        vm.startPrank(lockerBeaconOwner);
        Options memory lockerBeaconOpts;
        lockerBeaconOpts.referenceContract = "HoneyLockerV2.sol:HoneyLockerV2";
        Upgrades.upgradeBeacon(lockerBeacon, "HoneyLockerV3.sol:HoneyLockerV3", lockerBeaconOpts);
        vm.stopPrank();
        
        // upgrade BGTStation adapter beacon
        vm.startPrank(lockerBeaconOwner);
        Options memory adapterBeaconOpts;
        adapterBeaconOpts.referenceContract = "BGTStationAdapter.sol:BGTStationAdapter";
        Upgrades.upgradeBeacon(0x6571d9e2830ab0d500ffe557e94EA45762Fd8B8f, "BGTStationAdapterV2.sol:BGTStationAdapterV2", adapterBeaconOpts);
        vm.stopPrank();
    }
}

