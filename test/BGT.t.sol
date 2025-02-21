// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {BGTStationAdapter} from "../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IBGT} from "../src/utils/IBGT.sol";

contract BGTTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL_ALT);
        super.setUp();

        vm.prank(THJ);
        locker.setTreasury(treasury);

    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    function test_burnBGTForBERA(uint256 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = StdUtils.bound(amount, 1, type(uint32).max);
        StdCheats.deal(address(BGT), address(locker), amount);

        uint256 fees = queen.computeFees(THJ, false, amount);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.Redeem(address(locker), address(locker), amount);
        locker.burnBGTForBERA(amount);

        assertEq(BGT.unboostedBalanceOf(address(locker)), 0);
        assertEq(treasury.balance, amount - fees);
    }

    function test_queueBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(locker), validator, amount);
        locker.queueBoost(amount, validator);

        assertEq(BGT.unboostedBalanceOf(address(locker)), 0);
        assertEq(BGT.queuedBoost(address(locker)), amount);
    }

    function test_cancelBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        locker.queueBoost(amount, validator);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.CancelBoost(address(locker), validator, amount);
        locker.cancelQueuedBoost(amount, validator);
    }

    function test_activateBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        locker.queueBoost(amount, validator);

        vm.roll(block.number + 10001);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.ActivateBoost(address(locker), address(locker), validator, amount);
        locker.activateBoost(validator);
    }

    function test_queueDropBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        locker.queueBoost(amount, validator);
        vm.roll(block.number + 10001);
        locker.activateBoost(validator);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueDropBoost(address(locker), validator, amount);
        locker.queueDropBoost(amount, validator);
    }

    function test_cancelDropBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        locker.queueBoost(amount, validator);
        vm.roll(block.number + 10001);
        locker.activateBoost(validator);
        locker.queueDropBoost(amount, validator);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.CancelDropBoost(address(locker), validator, amount);
        locker.cancelDropBoost(amount, validator);
    }

    function test_dropBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint32).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        locker.queueBoost(amount, validator);

        vm.roll(block.number + 10001);

        locker.activateBoost(validator);
        locker.queueDropBoost(amount, validator);

        vm.roll(block.number + 10001);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.DropBoost(address(locker), validator, amount);
        locker.dropBoost(amount, validator);

        assertEq(BGT.unboostedBalanceOf(address(locker)), amount);
    }
}

