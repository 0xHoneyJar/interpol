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
import {Constants} from "../src/Constants.sol";

contract BGTTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    IBGT public constant BGT = IBGT(Constants.BGT);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));
        super.setUp();
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    function test_cancelQueuedBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint128).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        // test the delegate part
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(locker), THJ, amount);
        locker.delegateBGT(amount, THJ);

        assertEq(BGT.unboostedBalanceOf(address(locker)), 0);

        // test cancel boost
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.CancelBoost(address(locker), THJ, amount);
        locker.cancelQueuedBoost(amount, THJ);

        assertEq(BGT.unboostedBalanceOf(address(locker)), amount);
    }

    function test_dropBoost(uint128 amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        amount = uint128(StdUtils.bound(amount, 1, type(uint64).max));
        StdCheats.deal(address(BGT), address(locker), uint256(amount));

        // test the delegate part
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(locker), THJ, amount);
        locker.delegateBGT(amount, THJ);

        vm.roll(block.number + 10001);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.ActivateBoost(address(locker), THJ, amount);
        locker.activateBoost(THJ);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.DropBoost(address(locker), THJ, amount);
        locker.dropBoost(amount, THJ);

        assertEq(BGT.unboostedBalanceOf(address(locker)), amount);
    }
}

