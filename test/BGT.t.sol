// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {BaseTest} from "./Base.t.sol";
import {IBGT} from "../src/utils/IBGT.sol";

interface IBGTStaker {
    event Staked(address indexed staker, uint256 amount);
}

// prettier-ignore
contract BGTTest is BaseTest {
    function setUp() public override {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(7925685));

        super.setUp();
    }

    function test_cancelQueuedBoost(uint128 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        address user = _useOperator ? operator : THJ;
        uint128 amount = uint128(StdUtils.bound(_amount, uint(1e18), type(uint128).max / 2));

        StdCheats.deal(address(BGT), address(honeyLocker), amount);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(honeyLocker), validator, amount);
        honeyLocker.delegateBGT(amount, validator);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.CancelBoost(address(honeyLocker), validator, amount);
        honeyLocker.cancelQueuedBoost(amount, validator);
    }

    function test_dropBoost(uint128 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        address user = _useOperator ? operator : THJ;
        uint128 amount = uint128(StdUtils.bound(_amount, uint(1e18), type(uint128).max / 2));

        StdCheats.deal(address(BGT), address(honeyLocker), amount);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(honeyLocker), validator, amount);
        honeyLocker.delegateBGT(amount, validator);

        vm.roll(block.timestamp + 10001);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.ActivateBoost(address(honeyLocker), validator, amount);
        honeyLocker.activateBoost(validator);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.DropBoost(address(honeyLocker), validator, amount);
        honeyLocker.dropBoost(amount, validator);
    }
}

