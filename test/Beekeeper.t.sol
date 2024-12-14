// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {LibString} from "solady/utils/LibString.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {Constants} from "../src/Constants.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract BeekeeperTest is BaseTest {
    using LibString for uint256;
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
  function test_feesBERA(uint64 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(locker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = queen.protocolFees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referrer, address(0), pythonReferrerFees);
        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(THJTreasury, address(0), pythonTreasuryFees);
        vm.expectEmit(true, false, false, false, address(locker));
        emit HoneyLocker.HoneyLocker__Withdrawn(address(0), pythonWithdrawn);

        uint256 balanceOfTHJBefore = THJ.balance;

        locker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(address(THJTreasury).balance, pythonTreasuryFees, 1e16);
        assertApproxEqRel(referrer.balance, pythonReferrerFees, 1e16);
        assertApproxEqRel(THJ.balance, balanceOfTHJBefore + pythonWithdrawn, 1e16);
    }

    function test_feesERC20(uint64 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        MockERC20 token = new MockERC20();

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));
        token.mint(address(locker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = queen.protocolFees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referrer, address(token), pythonReferrerFees);
        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(THJTreasury, address(token), pythonTreasuryFees);
        vm.expectEmit(true, false, false, false, address(locker));
        emit HoneyLocker.HoneyLocker__Withdrawn(address(token), pythonWithdrawn);

        uint256 balanceOfTHJBefore = token.balanceOf(address(THJ));

        locker.withdrawERC20(address(token), amount);

        assertApproxEqRel(token.balanceOf(address(THJTreasury)), pythonTreasuryFees, 1e16);
        assertApproxEqRel(token.balanceOf(address(referrer)), pythonReferrerFees, 1e16);
        assertApproxEqRel(token.balanceOf(address(THJ)), balanceOfTHJBefore + pythonWithdrawn, 1e16);
    }

    function test_referrerOverride(uint64 _amount, bool _useOperator) external {
        address newReferrer = makeAddr("newReferrer");
        vm.prank(THJ);
        beekeeper.setReferrerOverride(referrer, newReferrer);

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(locker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = queen.protocolFees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(newReferrer, address(0), pythonReferrerFees);

        vm.prank(_useOperator ? operator : THJ);
        locker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(newReferrer.balance, pythonReferrerFees, 1e16);
        assertEq(referrer.balance, 0);
    }

    function test_referrerFeeShare(uint64 _amount, bool _useOperator) external {
        vm.prank(THJ);
        beekeeper.setReferrerFeeShare(referrer, 9000);

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(locker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = queen.protocolFees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.referrerFeeShare(referrer).toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referrer, address(0), pythonReferrerFees);

        vm.prank(_useOperator ? operator : THJ);
        locker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(referrer.balance, pythonReferrerFees, 1e16);
    }

    function test_overridingReferrerImpactsFeeShare(uint64 _amount) external prankAsTHJ(false) {
        address overridingReferrer = makeAddr("overridingReferrer");
        beekeeper.setReferrerFeeShare(referrer, 5000); // 50%
        
        uint256 referrerFeeShareInBps = beekeeper.referrerFeeShare(referrer);
        uint256 expectedReferrerFee = FPML.mulDivUp(_amount, referrerFeeShareInBps, 10000);

        beekeeper.setReferrerOverride(referrer, overridingReferrer);

        vm.deal(address(beekeeper), _amount);
        beekeeper.distributeFees(referrer, address(0), _amount);

        assertEq(overridingReferrer.balance, expectedReferrerFee);
        assertEq(referrer.balance, 0);

    }
}

