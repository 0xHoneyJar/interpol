// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {HoneyLockerV2} from "./mocks/HoneyLockerV2.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {BaseTest} from "./Base.t.sol";

interface IBGTStationGauge {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external returns (uint256);
    function setOperator(address operator) external;
    function earned(address account) external view returns (uint256);
}

contract BGTSTationTest is BaseTest {
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/

    // LBGT-WBERA gauge
    address public constant GAUGE   = 0x7a6b92457e7D7e7a5C1A2245488b850B7Da8E01D;
    // LBGT-WBERA LP token
    ERC20 public constant LP_TOKEN  = ERC20(0x6AcBBedEcD914dE8295428B4Ee51626a1908bB12);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        PROTOCOL = "BGTSTATION";
        /*
            Choosing this block number because the vault LBGT-WBERA is active
        */
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(7925685));

        super.setUp();

        vm.startPrank(THJ);

        honeyQueen.setProtocolOfTarget(address(GAUGE), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdraw(uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);

        vm.stopPrank();

        vm.label(address(GAUGE), "LBGT-WBERA Gauge");
        vm.label(address(LP_TOKEN), "LBGT-WBERA LP Token");
    }

    function test_initializeOnlyOnce() external prankAsTHJ(false) {
        vm.expectRevert();
        honeyLocker.initialize(THJ, address(honeyQueen), referral, false);
    }

    function test_singleDeposit(uint256 amountToDeposit, uint256 expiration, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;

        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);

        vm.expectEmit(true, true, false, false, address(honeyLocker));
        emit HoneyLocker.Deposited(address(LP_TOKEN), amountToDeposit);
        vm.expectEmit(true, false, false, false, address(honeyLocker));
        emit HoneyLocker.LockedUntil(address(LP_TOKEN), expiration);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, expiration);

        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), amountToDeposit);
    }

    function test_multipleDeposits(uint32[4] memory amounts, uint128[4] memory expirations, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        
        uint runningBalance;

        // mint, deposit the first amount
        uint256 amount = uint256(amounts[0]);
        uint256 expiration = uint256(expirations[0]);

        runningBalance += amount;
        StdCheats.deal(address(LP_TOKEN), user, amount);
        LP_TOKEN.approve(address(honeyLocker), amount);
        honeyLocker.depositAndLock(address(LP_TOKEN), amount, expiration);

        for (uint i = 1; i < amounts.length; i++) {
            uint256 _amount = uint256(amounts[i]);
            uint256 _expiration = uint256(expirations[i]);

            StdCheats.deal(address(LP_TOKEN), user, _amount);
            LP_TOKEN.approve(address(honeyLocker), _amount);

            // getting ready to revert if the new expiration is less than the current one
            if (expiration >_expiration) {
                vm.expectRevert(HoneyLocker.ExpirationNotMatching.selector);
            } else {
                // if the new expiration is greater than the current one, update the expiration
                // and add the amount to the running balance because successful deposit
                expiration = _expiration;
                runningBalance += _amount;
            }

            honeyLocker.depositAndLock(address(LP_TOKEN), _amount, _expiration);
        }

        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), runningBalance);
    }

    function test_singleWithdrawal(uint256 amountTDeposit, uint256 expiration, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;

        expiration = StdUtils.bound(expiration, 0, type(uint256).max - 1);

        StdCheats.deal(address(LP_TOKEN), user, amountTDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountTDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountTDeposit, expiration);

        // cannot withdraw too early if expiration is in the future
        if (expiration > block.timestamp) {
            vm.expectRevert(HoneyLocker.NotExpiredYet.selector);
            honeyLocker.withdrawLPToken(address(LP_TOKEN), amountTDeposit);
        }

        // move forward in time
        vm.warp(expiration + 1);

        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(LP_TOKEN), amountTDeposit);
        honeyLocker.withdrawLPToken(address(LP_TOKEN), amountTDeposit);

        assertEq(LP_TOKEN.balanceOf(THJ), amountTDeposit);
    }

    function test_stake(uint256 amountToDeposit, uint128 _expiration, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;

        amountToDeposit = bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(_expiration));

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IBGTStationGauge.Staked(address(honeyLocker), amountToDeposit);
        vm.expectEmit(true, true, false, true, address(honeyLocker));
        emit HoneyLocker.Staked(address(GAUGE), address(LP_TOKEN), amountToDeposit);
        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE), 
            amountToDeposit,
            abi.encodeWithSignature("stake(uint256)", amountToDeposit)
        );

        assertEq(LP_TOKEN.balanceOf(user), 0);
        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), 0);
    }

    function test_unstake(uint256 amountToDeposit, uint128 expiration, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;

        amountToDeposit = StdUtils.bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(expiration));

        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSignature("stake(uint256)", amountToDeposit)
        );

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IBGTStationGauge.Withdrawn(address(honeyLocker), amountToDeposit);
        vm.expectEmit(true, true, false, true, address(honeyLocker));
        emit HoneyLocker.Unstaked(address(GAUGE), address(LP_TOKEN), amountToDeposit);
        honeyLocker.unstake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSignature("withdraw(uint256)", amountToDeposit)
        );

        assertEq(LP_TOKEN.balanceOf(user), 0);
        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), amountToDeposit);
    }

    function test_claimRewards(uint256 amountToDeposit, uint128 _expiration, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;

        amountToDeposit = StdUtils.bound(amountToDeposit, 1, type(uint32).max);

        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(_expiration));
        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSignature("stake(uint256)", amountToDeposit)
        );

        vm.warp(block.timestamp + 10000);

        uint256 earned = IBGTStationGauge(GAUGE).earned(address(honeyLocker));

        vm.expectEmit(true, true, true, true, address(honeyLocker));
        emit HoneyLocker.RewardsClaimed(address(GAUGE));
        honeyLocker.claimRewards(
            address(GAUGE),
            abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );

        assertEq(BGT.unboostedBalanceOf(address(honeyLocker)), earned);
    }
}
