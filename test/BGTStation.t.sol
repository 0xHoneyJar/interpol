// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {BGTStationAdapter, IBGTStationGauge} from "../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract BGTStationTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    BGTStationAdapter   public adapter;
    BVA                 public lockerAdapter;   // adapter for BGT Station used by locker

    // BERA-HONEY gauge
    address     public constant GAUGE       = 0x0cc03066a3a06F3AC68D3A0D36610F52f7C20877;
    // BERA-HONEY LP token
    ERC20       public constant LP_TOKEN    = ERC20(0x3aD1699779eF2c5a4600e649484402DFBd3c503C);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        /*
            Choosing this block number because the vault LBGT-WBERA is active
        */
        vm.createSelectFork(RPC_URL_ALT);

        super.setUp();

        // Deploy adapter implementation that will be cloned
        address adapterLogic = address(new BGTStationAdapter());
        address adapterBeacon = address(new UpgradeableBeacon(adapterLogic, THJ));

        vm.startPrank(THJ);

        queen.setAdapterBeaconForProtocol("BGTSTATION", address(adapterBeacon));
        queen.setVaultForProtocol("BGTSTATION", GAUGE, address(LP_TOKEN), true);
        locker.registerAdapter("BGTSTATION");

        //locker.wildcard(address(GAUGE), 0, "");

        lockerAdapter = BVA(locker.adapterOfProtocol("BGTSTATION"));

        vm.stopPrank();

        vm.label(address(lockerAdapter), "BGTStationAdapter");
        vm.label(address(adapterBeacon), "BGTStationBeacon");
        vm.label(address(adapterLogic), "BGTStationLogic");
        vm.label(address(GAUGE), "BERA-HONEY Gauge");
        vm.label(address(LP_TOKEN), "BERA-HONEY LP Token");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    /*
        This test a single simple deposit.
        It checks ;
        - proper events
        - balance is updated
    */
    function test_singleDeposit(uint256 amountToDeposit, uint256 expiration, bool _useOperator) external prankAsTHJ(_useOperator) {
        expiration = StdUtils.bound(expiration, 1, type(uint256).max - 1);

        address user = _useOperator ? operator : THJ;
        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(locker), amountToDeposit);

        vm.expectEmit(true, true, false, false, address(locker));
        emit HoneyLocker.HoneyLocker__Deposited(address(LP_TOKEN), amountToDeposit);
        vm.expectEmit(true, false, false, false, address(locker));
        emit HoneyLocker.HoneyLocker__LockedUntil(address(LP_TOKEN), expiration);
        locker.depositAndLock(address(LP_TOKEN), amountToDeposit, expiration);

        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit);
    }

    /*
        This test multiple deposits.
        It checks ;
        - balance is updated
        - expiration is updated
    */
    function test_multipleDeposits(uint32[4] memory amounts, uint256[4] memory expirations, bool _useOperator) external prankAsTHJ(_useOperator) {
        for (uint i = 0; i < expirations.length; i++) {
            expirations[i] = StdUtils.bound(expirations[i], 1, type(uint256).max - 1);
        }

        uint runningBalance;
        address user = _useOperator ? operator : THJ;

        // mint, deposit the first amount
        uint256 amount = uint256(amounts[0]);
        uint256 expiration = expirations[0];

        runningBalance += amount;
        StdCheats.deal(address(LP_TOKEN), user, amount);
        LP_TOKEN.approve(address(locker), amount);
        locker.depositAndLock(address(LP_TOKEN), amount, expiration);

        for (uint i = 1; i < amounts.length; i++) {
            uint256 _amount = uint256(amounts[i]);
            uint256 _expiration = uint256(expirations[i]);

            StdCheats.deal(address(LP_TOKEN), user, _amount);
            LP_TOKEN.approve(address(locker), _amount);

            // getting ready to revert if the new expiration is less than the current one
            if (expiration >_expiration) {
                vm.expectRevert(HoneyLocker.HoneyLocker__ExpirationNotMatching.selector);
            } else {
                // if the new expiration is greater than the current one, update the expiration
                // and add the amount to the running balance because successful deposit
                expiration = _expiration;
                runningBalance += _amount;
            }

            locker.depositAndLock(address(LP_TOKEN), _amount, _expiration);
        }

        assertEq(LP_TOKEN.balanceOf(address(locker)), runningBalance);
    }

    /*
        This test a single simple withdrawal.
        It checks ;
        - proper events
        - expiration is respected
        - withdrawal is successful
    */
    function test_singleWithdrawal(uint256 amountTDeposit, uint256 expiration, bool _useOperator) external prankAsTHJ(_useOperator) {
        expiration = StdUtils.bound(expiration, 1, type(uint256).max - 1);
        address user = _useOperator ? operator : THJ;
        StdCheats.deal(address(LP_TOKEN), user, amountTDeposit);

        LP_TOKEN.approve(address(locker), amountTDeposit);
        locker.depositAndLock(address(LP_TOKEN), amountTDeposit, expiration);

        // cannot withdraw too early if expiration is in the future
        if (expiration > block.timestamp) {
            vm.expectRevert(HoneyLocker.HoneyLocker__NotExpiredYet.selector);
            locker.withdrawLPToken(address(LP_TOKEN), amountTDeposit);
        }

        // move forward in time
        vm.warp(expiration + 1);

        vm.expectEmit(true, false, false, true, address(locker));
        emit HoneyLocker.HoneyLocker__Withdrawn(address(LP_TOKEN), amountTDeposit);
        locker.withdrawLPToken(address(LP_TOKEN), amountTDeposit);

        assertEq(LP_TOKEN.balanceOf(THJ), amountTDeposit);
    }

    /*
        This test a single stake.
        It checks ;
        - proper events
        - proper balances
    */
    function test_stake(uint256 amountToDeposit, bool _useOperator) external prankAsTHJ(_useOperator) {
        amountToDeposit = StdUtils.bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IBGTStationGauge.Staked(address(lockerAdapter), amountToDeposit);
        vm.expectEmit(true, true, false, true, address(locker));
        emit HoneyLocker.HoneyLocker__Staked(address(GAUGE), address(LP_TOKEN), amountToDeposit);
        locker.stake(address(GAUGE), amountToDeposit);

        assertEq(LP_TOKEN.balanceOf(THJ), 0);
        assertEq(LP_TOKEN.balanceOf(address(locker)), 0);
        assertEq(LP_TOKEN.balanceOf(address(lockerAdapter)), 0);
    }

    /*
        This test a single unstake.
        It checks ;
        - proper events
        - proper balances
    */
    function test_unstake(uint256 amountToDeposit, bool _useOperator) external prankAsTHJ(_useOperator) {
        amountToDeposit = StdUtils.bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        locker.stake(address(GAUGE), amountToDeposit);

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IBGTStationGauge.Withdrawn(address(lockerAdapter), amountToDeposit);
        vm.expectEmit(true, true, false, true, address(locker));
        emit HoneyLocker.HoneyLocker__Unstaked(address(GAUGE), address(LP_TOKEN), amountToDeposit);
        locker.unstake(address(GAUGE), amountToDeposit);

        assertEq(LP_TOKEN.balanceOf(THJ), 0);
        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit);
        assertEq(LP_TOKEN.balanceOf(address(lockerAdapter)), 0);
    }

    /*
        This test claiming rewards, which should be only BGT.
        It checks ;
        - proper events
        - proper balances
    */
    function test_claimRewards(uint256 amountToDeposit, bool _useOperator) external prankAsTHJ(_useOperator) {
        amountToDeposit = StdUtils.bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 10000);

        uint256 earned = IBGTStationGauge(GAUGE).earned(address(lockerAdapter));

        vm.expectEmit(true, true, true, true, address(locker));
        emit HoneyLocker.HoneyLocker__Claimed(address(GAUGE), address(BGT), earned);
        locker.claim(address(GAUGE));

        assertEq(BGT.unboostedBalanceOf(address(locker)), earned);
        assertEq(BGT.unboostedBalanceOf(address(lockerAdapter)), 0);
        assertEq(BGT.unboostedBalanceOf(THJ), 0);
    }

    function test_cannotWithdrawRewardThroughLPWithdrawFunction() external prankAsTHJ(false) {
        MockERC20 rewardToken = new MockERC20();
        // deal some to locker
        rewardToken.mint(address(locker), 100 ether);
        // try to withdraw thrugh LP withdraw function
        vm.expectRevert(HoneyLocker.HoneyLocker__HasToBeLPToken.selector);
        locker.withdrawLPToken(address(rewardToken), 1);
    }
}


