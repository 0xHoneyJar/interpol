// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {console} from "forge-std/console.sol";

import {BaseTest} from "./Base.t.sol";
import {BGTStationTest} from "./BGTStation.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {BGTStationAdapter, IBGTStationGauge} from "../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {IBGM, Lot, Position} from "../src/utils/IBGM.sol";

contract BGMTest is BGTStationTest {
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    uint256 constant MAX_LOT_SIZE = 100 ether;
    bytes public VALIDATOR_PUBKEY = hex"83d0f90cdedaac1450c8dc08cfa644ae02f5918572041c2fca7df8b55336682cb5edbccadd6e77129de425844e147d02";
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL_MAINNET);
        super.setUp();

        vm.prank(THJ);
        locker.setTreasury(treasury);
    }

    function _setUpStake(uint256 amountToDeposit) internal {
        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 10000);

        uint256 earned = IBGTStationGauge(GAUGE).earned(address(lockerAdapter));

        locker.wildcard(address(GAUGE), 0, "");

        assertEq(BGM.getBalance(address(locker)), earned);
        assertEq(BGM.getBalance(address(lockerAdapter)), 0);
        assertEq(BGM.getBalance(THJ), 0);
    }

    /*###############################################################
                            HELPER
    ###############################################################*/
    function contains(address[] memory addresses, address target) internal pure returns (bool) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == target) return true;
        }
        return false;
    }

    function _assertBalance(
        bytes memory pubkey,
        address user,
        uint256 expectedPending,
        uint256 expectedQueued,
        uint256 expectedConfirmed,
        string memory message
    ) internal view {
        Position memory p = BGM.getDelegatedBoostBalance(pubkey, user);
        assertEq(p.pending, expectedPending, string.concat(message, " - pending balance incorrect"));
        assertEq(p.queued, expectedQueued, string.concat(message, " - queued balance incorrect"));
        assertEq(
            p.confirmed, expectedConfirmed, string.concat(message, " - confirmed balance incorrect")
        );
    }
    
    function _assertUnboostBalance(
        bytes memory pubkey,
        address user,
        uint256 expectedPending,
        uint256 expectedQueued,
        uint256 expectedConfirmed,
        string memory message
    ) internal view {
        Position memory p = BGM.getDelegatedUnboostBalance(pubkey, user);
        assertEq(p.pending, expectedPending, string.concat(message, " - pending balance incorrect"));
        assertEq(p.queued, expectedQueued, string.concat(message, " - queued balance incorrect"));
        assertEq(
            p.confirmed, expectedConfirmed, string.concat(message, " - confirmed balance incorrect")
        );
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    function testBGM_burnBGMForBERA(uint256 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = StdUtils.bound(amount, 1, type(uint32).max);
        StdCheats.deal(address(BGT), address(locker), amount);
        _setUpStake(amount);

        uint256 burnAmount = BGM.getBalance(address(locker));

        uint256 fees = queen.computeFees(THJ, false, burnAmount);

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.Redeem(address(locker), burnAmount);
        locker.burnBGMForBERA(burnAmount);

        assertEq(BGM.getBalance(address(locker)), 0);
        assertEq(treasury.balance, burnAmount - fees);
    }

    function testBGM_contributeBGM(uint256 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = StdUtils.bound(amount, 10_000 ether, 10_000_000 ether);
        StdCheats.deal(address(BGT), address(locker), amount);
        _setUpStake(amount);

        vm.assume(BGM.getBalance(address(locker)) >= 0.05 ether);

        uint256 toBeContributed = 0.05 ether;
        uint256 balanceBefore = BGM.getBalance(address(locker));

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.Contribute(address(locker), 0, toBeContributed);
        locker.contributeBGM(toBeContributed);

        uint256 balanceAfter = BGM.getBalance(address(locker));

        assertEq(balanceAfter, balanceBefore - toBeContributed);

        Lot memory openLot = BGM.getOpenLot();
        Lot[] memory ongoingLots = BGM.getOngoingLots();

        assertEq(openLot.id, 0);
        assertEq(openLot.stakers[0], address(locker));
        assertEq(openLot.stakes[0], toBeContributed);
        assertEq(openLot.shares, toBeContributed);
        assertEq(openLot.startAt, 0);
        assertEq(ongoingLots.length, 0);
    }

    function testBGM_queueBoostBGM(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));
        _setUpStake(amount);

        uint128 boostAmount = uint128(BGM.getBalance(address(locker)));

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.Delegated(VALIDATOR_PUBKEY, address(locker), boostAmount);
        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        _assertBalance(VALIDATOR_PUBKEY, address(locker), 0, boostAmount, 0, "After delegation - should be queued");

        vm.roll(block.number + BGT.activateBoostDelay() + 1);
        BGM.activate(VALIDATOR_PUBKEY);

        _assertBalance(VALIDATOR_PUBKEY, address(locker), 0, 0, boostAmount, "After activation - should be confirmed");
    }

    function testBGM_cancelQueuedBoostBGM(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));
        _setUpStake(amount);

        uint128 balance = uint128(BGM.getBalance(address(locker)));
        uint128 boostAmount = balance / 2;

        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);
        vm.roll(block.number + 100);
        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.DelegationCancelled(VALIDATOR_PUBKEY, address(locker), boostAmount);
        locker.cancelQueuedBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        assertEq(BGM.getBalance(address(locker)), boostAmount);
    }

    function testBGM_queueDropBoostBGM(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));
        _setUpStake(amount);

        uint128 boostAmount = uint128(BGM.getBalance(address(locker)));

        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        vm.roll(block.number + BGT.activateBoostDelay() + 1);
        BGM.activate(VALIDATOR_PUBKEY);

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.UnbondQueued(VALIDATOR_PUBKEY, address(locker), boostAmount);
        locker.queueDropBoostBGM(boostAmount, VALIDATOR_PUBKEY);
        _assertBalance(VALIDATOR_PUBKEY, address(locker), 0, 0, 0, "After unbond - should be no balance");
        _assertUnboostBalance(VALIDATOR_PUBKEY, address(locker), 0, boostAmount, 0, "After queue unboost - should be in queued");
    }

    function testBGM_cancelDropBoostBGM(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));
        _setUpStake(amount);

        uint128 boostAmount = uint128(BGM.getBalance(address(locker)));

        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        vm.roll(block.number + BGT.activateBoostDelay() + 1);
        BGM.activate(VALIDATOR_PUBKEY);

        locker.queueDropBoostBGM(boostAmount / 2, VALIDATOR_PUBKEY);
        vm.roll(block.number + 100);
        locker.queueDropBoostBGM(boostAmount / 2, VALIDATOR_PUBKEY);

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.UnbondCancelled(VALIDATOR_PUBKEY, address(locker), boostAmount / 2);
        locker.cancelDropBoostBGM(boostAmount / 2, VALIDATOR_PUBKEY);
        _assertBalance(VALIDATOR_PUBKEY, address(locker), 0, 0, boostAmount / 2, "After cancel unbond - should have balance");
    }

    function testBGM_dropBoostBGM(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));
        _setUpStake(amount);

        uint128 boostAmount = uint128(BGM.getBalance(address(locker)));

        locker.queueBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        vm.roll(block.number + BGT.activateBoostDelay() + 1);
        BGM.activate(VALIDATOR_PUBKEY);

        locker.queueDropBoostBGM(boostAmount, VALIDATOR_PUBKEY);

        vm.roll(block.number + BGT.dropBoostDelay() + 1);

        BGM.deactivate(VALIDATOR_PUBKEY);
        _assertUnboostBalance(VALIDATOR_PUBKEY, address(locker), 0, 0, boostAmount, "After unbond - should be in confirmed");

        vm.expectEmit(true, false, false, true, address(BGM));
        emit IBGM.Unbonded(VALIDATOR_PUBKEY, address(locker), boostAmount);
        locker.dropBoostBGM(boostAmount, VALIDATOR_PUBKEY);
        _assertUnboostBalance(VALIDATOR_PUBKEY, address(locker), 0, 0, 0, "After unbond - should be no confirmed");
        assertEq(BGM.getBalance(address(locker)), boostAmount, "After unbond - should be in balance");
    }
}

