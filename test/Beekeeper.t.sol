// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {BaseTest} from "./Base.t.sol";

contract BeekeeperTest is BaseTest {
    using LibString for uint256;
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
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
    }

    function test_feesBERA(uint64 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(honeyLocker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(0), pythonReferrerFees);
        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(treasury, address(0), pythonTreasuryFees);
        vm.expectEmit(true, false, false, false, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(0), pythonWithdrawn);

        uint256 balanceOfTHJBefore = THJ.balance;

        honeyLocker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(address(treasury).balance, pythonTreasuryFees, 1e16);
        assertApproxEqRel(referral.balance, pythonReferrerFees, 1e16);
        assertApproxEqRel(THJ.balance, balanceOfTHJBefore + pythonWithdrawn, 1e16);
    }

    function test_feesERC20(uint64 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        MockERC20 token = new MockERC20();

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));
        token.mint(address(honeyLocker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(token), pythonReferrerFees);
        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(treasury, address(token), pythonTreasuryFees);
        vm.expectEmit(true, false, false, false, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(token), pythonWithdrawn);

        uint256 balanceOfTHJBefore = token.balanceOf(address(THJ));

        honeyLocker.withdrawERC20(address(token), amount);

        assertApproxEqRel(token.balanceOf(address(treasury)), pythonTreasuryFees, 1e16);
        assertApproxEqRel(token.balanceOf(address(referral)), pythonReferrerFees, 1e16);
        assertApproxEqRel(token.balanceOf(address(THJ)), balanceOfTHJBefore + pythonWithdrawn, 1e16);
    }

    function test_referrerOverride(uint64 _amount, bool _useOperator) external {
        address newReferrer = makeAddr("newReferrer");
        vm.prank(THJ);
        beekeeper.setReferrerOverride(referral, newReferrer);

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(honeyLocker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(newReferrer, address(0), pythonReferrerFees);

        vm.prank(_useOperator ? operator : THJ);
        honeyLocker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(newReferrer.balance, pythonReferrerFees, 1e16);
        assertEq(referral.balance, 0);
    }

    function test_referrerFeeShare(uint64 _amount, bool _useOperator) external {
        vm.prank(THJ);
        beekeeper.setReferrerFeeShare(referral, 9000);

        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));

        vm.deal(address(honeyLocker), amount);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.referrerFeeShare(referral).toString();
        inputs[6] = "--amount";
        inputs[7] = amount.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, false, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(0), pythonReferrerFees);

        vm.prank(_useOperator ? operator : THJ);
        honeyLocker.withdrawBERA(amount);

        // check balances
        assertApproxEqRel(referral.balance, pythonReferrerFees, 1e16);
    }

    function test_overridingReferrerImpactsFeeShare(uint64 _amount) external prankAsTHJ(false) {
        address overridingReferrer = makeAddr("overridingReferrer");
        beekeeper.setReferrerFeeShare(referral, 5000); // 50%
        
        uint256 referrerFeeShareInBps = beekeeper.referrerFeeShare(referral);
        uint256 expectedReferrerFee = FPML.mulDivUp(_amount, referrerFeeShareInBps, 10000);

        beekeeper.setReferrerOverride(referral, overridingReferrer);

        vm.deal(address(beekeeper), _amount);
        beekeeper.distributeFees(referral, address(0), _amount);

        assertEq(overridingReferrer.balance, expectedReferrerFee);
        assertEq(referral.balance, 0);

    }
}
