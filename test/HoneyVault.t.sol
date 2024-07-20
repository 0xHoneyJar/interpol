// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";
import {HoneyVault} from "../src/HoneyVault.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {HoneyVaultV2} from "./mocks/HoneyVaultV2.sol";
import {FakeVault} from "./mocks/FakeVault.sol";
import {FakeGauge} from "./mocks/FakeGauge.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";

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
        honeyQueen.setIsStakingContractAllowed(address(HONEYBERA_STAKING), true);
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("stake(uint256)")),
            "stake",
            address(HONEYBERA_STAKING),
            true
        );
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("withdraw(uint256)")),
            "unstake",
            address(HONEYBERA_STAKING),
            true
        );
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("getReward(address)")),
            "rewards",
            address(HONEYBERA_STAKING),
            true
        );
        vaultToBeCloned = new HoneyVault();
        honeyVault = HoneyVault(payable(vaultToBeCloned.clone()));
        honeyVault.initialize(THJ, address(honeyQueen), referral, false);
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
            referral,
            false
        );
        assertEq(address(vaultToBeCloned.owner()), address(this));
        // now we clone the vault
        honeyVault = HoneyVault(payable(vaultToBeCloned.clone()));
        assertEq(address(honeyVault.owner()), address(0));
        // initialize clone
        honeyVault.initialize(address(this), address(honeyQueen), referral, false);
        assertEq(address(honeyVault.owner()), address(this));
    }

    function test_singleDepositAndLock() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);

        vm.expectEmit(true, true, false, false, address(honeyVault));
        emit HoneyVault.DepositedAndLocked(address(HONEYBERA_LP), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        assertEq(HONEYBERA_LP.balanceOf(address(honeyVault)), balance);
    }

    function test_multipleDeposits() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        // prettier-ignore
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration);

        // cannot deposit with a different expiration
        vm.expectRevert(HoneyVault.ExpirationNotMatching.selector);
        // prettier-ignore
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration - 1);

        // deposit
        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.DepositedAndLocked(address(HONEYBERA_LP), balance / 2);
        // prettier-ignore
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration);
    }

    function test_stakeAndUnstake() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        vm.expectEmit(true, true, false, true, address(honeyVault));
        // prettier-ignore
        emit HoneyVault.Staked(address(HONEYBERA_STAKING), address(HONEYBERA_LP), balance);
        honeyVault.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );
        assertEq(
            HONEYBERA_LP.balanceOf(THJ),
            0,
            "post-stake balance should be O"
        );

        vm.expectEmit(true, true, false, true, address(honeyVault));
        emit HoneyVault.Unstaked(
            address(HONEYBERA_STAKING),
            address(HONEYBERA_LP),
            balance
        );
        honeyVault.unstake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("withdraw(uint256)", balance)
        );
        assertEq(
            HONEYBERA_LP.balanceOf(address(honeyVault)),
            balance,
            "post-unstake balance should be equal to initial balance"
        );
    }

    function test_claimRewards() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        honeyVault.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        uint256 bgtBalanceBefore = BGT.balanceOf(address(honeyVault));
        // deal some BGT
        StdCheats.deal(address(BGT), address(honeyVault), 1);
        honeyVault.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("getReward(address)", address(honeyVault))
        );
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
        honeyVault.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );
        StdCheats.deal(address(BGT), address(honeyVault), 10e18);
        honeyVault.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("getReward(address)", address(honeyVault))
        );

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
        honeyVault.withdrawLPToken(address(HONEYBERA_LP), balance);
        // move forward in time
        vm.warp(expiration + 1);
        // should be able to withdraw
        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.Withdrawn(address(HONEYBERA_LP), balance);
        honeyVault.withdrawLPToken(address(HONEYBERA_LP), balance);
    }

    function test_feesBERA() external prankAsTHJ {
        // get the BERA from BGT !
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        honeyVault.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        StdCheats.deal(address(BGT), address(honeyVault), 10e18);
        honeyVault.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("getReward(address)", address(honeyVault))
        );
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

    function test_cannotWithdrawNFT() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        GaugeAsNFT gauge = new GaugeAsNFT(address(HONEYBERA_LP));
        honeyQueen.setIsStakingContractAllowed(address(gauge), true);
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("stake(uint256)")),
            "stake",
            address(gauge),
            true
        );
        honeyVault.stake(
            address(HONEYBERA_LP),
            address(gauge),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );
        // block the nft from being transfered
        honeyQueen.setIsTokenBlocked(address(gauge), true);
        // should fail
        vm.expectRevert(HoneyVault.TokenBlocked.selector);
        honeyVault.withdrawERC721(address(gauge), 0);
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
        honeyVaultV2.initialize(THJ, address(honeyQueen), referral, false);

        // migration should fail because haven't set it in honey queen
        vm.expectRevert(HoneyVault.MigrationNotEnabled.selector);
        honeyVault.migrate(
            SLA.addresses(address(HONEYBERA_LP)),
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
        honeyVault.migrate(
            SLA.addresses(address(HONEYBERA_LP)),
            payable(address(honeyVaultV2))
        );
        assertEq(HONEYBERA_LP.balanceOf(address(honeyVaultV2)), balance);
    }

    function test_cannotCheatSelector() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, uint256(1));

        honeyVault.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        // attacker tries to withdraw through claim function
        vm.startPrank(address(0xaaaaa));
        vm.expectRevert(HoneyVault.SelectorNotAllowed.selector);
        honeyVault.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("withdraw(uint256)", balance)
        );
        vm.stopPrank();
    }
}
