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

contract UpdateTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    address lockerBeacon            = 0xD57848B26aBed18E36Fdb368E45F081C3A8C9980;
    address honeyQueenProxy         = 0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B;

    address honeyQueenOwner         = 0xDe81B20B6801d99EFEaEcEd48a11ba025180b8cc;
    address lockerBeaconOwner       = 0xd6C0E5F5F201f95F660bB7CFbb214Bd81dd4AB87;
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
}

