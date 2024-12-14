// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {KodiakAdapter, IKodiakFarm, XKDK} from "../src/adapters/KodiakAdapter.sol";
import {KodiakAdapterOld} from "./mocks/KodiakAdapterOld.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {Constants} from "../src/Constants.sol";



contract UpgradesTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    BGTStationAdapter   public adapter;
    BVA                 public lockerAdapter;   // adapter for BGT Station used by locker

    // LBGT-WBERA gauge
    address public constant     GAUGE       = 0x7a6b92457e7D7e7a5C1A2245488b850B7Da8E01D;
    // LBGT-WBERA LP token
    ERC20   public constant     LP_TOKEN    = ERC20(0x6AcBBedEcD914dE8295428B4Ee51626a1908bB12);
    IBGT    public constant     BGT         = IBGT(Constants.BGT);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));

        super.setUp();

        // Deploy adapter implementation that will be cloned
        oldAdapter = new KodiakAdapterOld();
        newAdapter = new KodiakAdapter();

        vm.startPrank(THJ);

        queen.setAdapterForProtocol("KODIAK", address(oldAdapter));
        queen.setVaultForProtocol("KODIAK", address(GAUGE), address(LP_TOKEN), true);
        locker.registerVault(address(GAUGE), false);

        lockerAdapter = BVA(locker.vaultToAdapter(address(GAUGE)));

        vm.stopPrank();

        vm.label(address(oldAdapter), "KodiakAdapterOld");
        vm.label(address(newAdapter), "KodiakAdapter");
        vm.label(address(lockerAdapter), "LockerAdapter");
        vm.label(address(GAUGE), "Kodiak Gauge");
        vm.label(address(LP_TOKEN), "Kodiak LP Token");
        vm.label(address(KODIAKV3), "KodiakV3");
        vm.label(address(xKDK), "XKDK");
        vm.label(address(KDK), "KDK");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    /*###############################################################
    ###############################################################*/
}

