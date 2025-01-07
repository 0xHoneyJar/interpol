// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {BGTStationAdapter, IBGTStationGauge} from "../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IBGT} from "../src/utils/IBGT.sol";

contract MultiAdaptersTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    BGTStationAdapter   public adapter;
    BVA                 public lockerAdapter;


    // BERA-HONEY gauge
    address     public constant GAUGE1          = 0x0cc03066a3a06F3AC68D3A0D36610F52f7C20877;
    // BERA-HONEY LP token
    ERC20       public constant LP_TOKEN1       = ERC20(0x3aD1699779eF2c5a4600e649484402DFBd3c503C);

    // BERA-WBTC gauge
    address public constant     GAUGE2          = 0x67993Fc90A8EC45625447Ad2ff454cfD3fbE9d79;
    // BERA-WBTC LP token
    ERC20   public constant     LP_TOKEN2       = ERC20(0x4A782a6bA2e47367A4b2A1551815c27dc15F4795);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL_ALT);

        super.setUp();

        // Deploy adapter implementation that will be cloned
        address adapterLogic = address(new BGTStationAdapter());
        address adapterBeacon = address(new UpgradeableBeacon(adapterLogic, THJ));

        vm.startPrank(THJ);

        queen.setAdapterBeaconForProtocol("BGTSTATION", address(adapterBeacon));

        queen.setVaultForProtocol("BGTSTATION", GAUGE1, address(LP_TOKEN1), true);
        queen.setVaultForProtocol("BGTSTATION", GAUGE2, address(LP_TOKEN2), true);
        locker.registerAdapter("BGTSTATION");
        lockerAdapter = BVA(locker.adapterOfProtocol("BGTSTATION"));

        vm.stopPrank();

        vm.label(address(lockerAdapter), "BGTStationAdapter");
        vm.label(address(GAUGE1), "LBGT-WBERA Gauge");
        vm.label(address(LP_TOKEN1), "LBGT-WBERA LP Token");
        vm.label(address(GAUGE2), "YEET-WBERA Gauge");
        vm.label(address(LP_TOKEN2), "YEET-WBERA LP Token");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    /*###############################################################
        We test that the locker works with multiple vaults for the same protocol
        but for different gauges.
    ###############################################################*/
    function test_LockerWorksWithMultipleAdaptersForSameProtocol(
        uint64 _amountToDeposit1,
        uint64 _amountToDeposit2
    ) public prankAsTHJ(false) {
        uint256 amountToDeposit1 = StdUtils.bound(_amountToDeposit1, 1, type(uint64).max);
        uint256 amountToDeposit2 = StdUtils.bound(_amountToDeposit2, 1, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN1), address(locker), amountToDeposit1);
        StdCheats.deal(address(LP_TOKEN2), address(locker), amountToDeposit2);

        vm.expectEmit(true, false, false, true, address(GAUGE1));
        emit IBGTStationGauge.Staked(address(lockerAdapter), amountToDeposit1);
        vm.expectEmit(true, true, false, true, address(locker));
        emit HoneyLocker.HoneyLocker__Staked(address(GAUGE1), address(LP_TOKEN1), amountToDeposit1);
        locker.stake(address(GAUGE1), amountToDeposit1);

        vm.expectEmit(true, false, false, true, address(GAUGE2));
        emit IBGTStationGauge.Staked(address(lockerAdapter), amountToDeposit2);
        vm.expectEmit(true, true, false, true, address(locker));
        emit HoneyLocker.HoneyLocker__Staked(address(GAUGE2), address(LP_TOKEN2), amountToDeposit2);
        locker.stake(address(GAUGE2), amountToDeposit2);

        assertEq(LP_TOKEN1.balanceOf(address(locker)), 0);
        assertEq(LP_TOKEN1.balanceOf(address(lockerAdapter)), 0);
        assertEq(LP_TOKEN2.balanceOf(address(locker)), 0);
        assertEq(LP_TOKEN2.balanceOf(address(lockerAdapter)), 0);

        // unstake from both gauges and check balance
        locker.unstake(address(GAUGE1), amountToDeposit1);
        locker.unstake(address(GAUGE2), amountToDeposit2);

        assertEq(LP_TOKEN1.balanceOf(address(locker)), amountToDeposit1);
        assertEq(LP_TOKEN1.balanceOf(address(lockerAdapter)), 0);
        assertEq(LP_TOKEN2.balanceOf(address(locker)), amountToDeposit2);
        assertEq(LP_TOKEN2.balanceOf(address(lockerAdapter)), 0);
    }
}

