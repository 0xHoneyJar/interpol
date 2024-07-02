// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HoneyVault, IStakingContract} from "../src/HoneyVault.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {HoneyVaultV2} from "./mocks/HoneyVaultV2.sol";
import {FakeVault} from "./mocks/FakeVault.sol";

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
}

contract HoneyVaultTest is Test {
    using LibString for uint256;

    HoneyVault public vaultToBeCloned;
    HoneyVault public honeyVault;
    HoneyQueen public honeyQueen;

    uint256 public expiration;
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);

    // IMPORTANT
    // BARTIO ADDRESSES
    // prettier-ignore
    ERC20 public constant HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    // prettier-ignore
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    // prettier-ignore
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/");
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury);
        // prettier-ignore
        honeyQueen.setLPTokenToStakingContract(address(HONEYBERA_LP), address(HONEYBERA_STAKING));
        vaultToBeCloned = new HoneyVault();
        honeyVault = HoneyVault(payable(vaultToBeCloned.clone()));
        honeyVault.initialize(THJ, address(honeyQueen), referral);
        vm.stopPrank();

        vm.label(address(honeyVault), "HoneyVault");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(msg.sender, "THJ");
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_initializeOriginalHasNoImpact() external {
        vaultToBeCloned.initialize(
            address(this),
            address(honeyQueen),
            referral
        );
        assertEq(address(vaultToBeCloned.owner()), address(this));
        // now we clone the vault
        honeyVault = HoneyVault(payable(vaultToBeCloned.clone()));
        assertEq(address(honeyVault.owner()), address(0));
        // initialize clone
        honeyVault.initialize(address(this), address(honeyQueen), referral);
        assertEq(address(honeyVault.owner()), address(this));
    }

    function test_depositAndLock() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);

        vm.expectEmit(true, false, false, true, address(HONEYBERA_STAKING));
        emit IStakingContract.Staked(address(honeyVault), balance);
        vm.expectEmit(true, true, false, false, address(honeyVault));
        emit HoneyVault.DepositedAndLocked(address(HONEYBERA_LP), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        assertEq(honeyVault.balances(address(HONEYBERA_LP)), balance);
    }

    function test_claimRewards() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        uint256 bgtBalanceBefore = BGT.balanceOf(address(honeyVault));
        // deal some BGT
        StdCheats.deal(address(BGT), address(honeyVault), 1);
        honeyVault.claimRewards(address(HONEYBERA_LP));
        // balance should have increased!
        uint256 bgtBalanceAfter = BGT.balanceOf(address(honeyVault));
        // prettier-ignore
        assertTrue(bgtBalanceAfter > bgtBalanceBefore, "BGT balance did not increase!");
    }

    function test_burnBGTForBERA() external prankAsTHJ {
        // deposit, get some rewards
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        StdCheats.deal(address(BGT), address(honeyVault), 10e18);
        honeyVault.claimRewards(address(HONEYBERA_LP));

        // time to burn
        uint256 beraBalanceBefore = address(honeyVault).balance;
        uint256 bgtBalance = BGT.balanceOf(address(honeyVault));
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.Redeem(address(honeyVault), address(honeyVault), bgtBalance);
        honeyVault.burnBGTForBERA(bgtBalance);
        uint256 beraBalanceAfter = address(honeyVault).balance;
        // prettier-ignore
        assertTrue(beraBalanceAfter > beraBalanceBefore, "BERA balance did not increase!");
    }

    function test_withdrawLPToken() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        // cannot withdraw too early
        vm.expectRevert(HoneyVault.NotExpiredYet.selector);
        honeyVault.withdrawLPTokens(address(HONEYBERA_LP), balance);
        // move forward in time
        vm.warp(expiration + 1);
        // should be able to withdraw
        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.Withdrawn(address(HONEYBERA_LP), balance);
        honeyVault.withdrawLPTokens(address(HONEYBERA_LP), balance);
    }

    function test_feesBERA() external prankAsTHJ {
        // get the BERA from BGT !
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        StdCheats.deal(address(BGT), address(honeyVault), 10e18);
        honeyVault.claimRewards(address(HONEYBERA_LP));
        uint256 bgtBalance = BGT.balanceOf(address(honeyVault));
        honeyVault.burnBGTForBERA(bgtBalance);

        string[] memory inputs = new string[](6);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--amount";
        inputs[5] = bgtBalance.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonFees, uint256 pythonWithdrawn) = abi.decode(
            res,
            (uint256, uint256)
        );

        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.Withdrawn(address(0), pythonWithdrawn);
        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.Fees(referral, address(0), pythonFees);

        honeyVault.withdrawBERA(bgtBalance);
    }

    function test_migration() external prankAsTHJ {
        // deposit first some into contract
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        // deploy base honeyvault v2
        HoneyVaultV2 baseVault = new HoneyVaultV2();
        // clone it
        HoneyVaultV2 honeyVaultV2 = HoneyVaultV2(payable(baseVault.clone()));
        honeyVaultV2.initialize(THJ, address(honeyQueen), referral);

        // migration should fail because haven't set it in honey queen
        vm.expectRevert(HoneyVault.MigrationNotEnabled.selector);
        honeyVault.migrateLPToken(
            address(HONEYBERA_LP),
            payable(address(honeyVaultV2))
        );

        // set hashcode in honeyqueen then attempt migration
        honeyQueen.setMigrationFlag(
            true,
            address(honeyVault).codehash,
            address(honeyVaultV2).codehash
        );
        vm.expectEmit(true, false, false, false, address(honeyVaultV2));
        //using HoneyVault V1 to emit because for some reasons can't
        // access the event in V2
        emit HoneyVault.DepositedAndLocked(address(HONEYBERA_LP), balance);
        vm.expectEmit(true, true, true, false, address(honeyVault));
        emit HoneyVault.Migrated(
            address(HONEYBERA_LP),
            address(honeyVault),
            address(honeyVaultV2)
        );
        honeyVault.migrateLPToken(
            address(HONEYBERA_LP),
            payable(address(honeyVaultV2))
        );
        // check balances is identical
        assertEq(honeyVaultV2.balances(address(HONEYBERA_LP)), balance);
    }
}
