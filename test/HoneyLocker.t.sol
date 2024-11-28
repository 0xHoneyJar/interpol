// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {HoneyLockerV2} from "./mocks/HoneyLockerV2.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
    event QueueBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event CancelBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event ActivateBoost(address indexed sender, address indexed validator);
    event DropBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );

    function minter() external view returns (address);
    function mint(address distributor, uint256 amount) external;
}

interface IBGTStaker {
    event Staked(address indexed staker, uint256 amount);
}

/*
    This test file tests all the functionnalities of the locker
    using the BEX LP Tokens on BGT Station only.
*/
// prettier-ignore
contract HoneyLockerTest is Test {
    using LibString for uint256;

    LockerFactory public factory;
    HoneyLocker public honeyLocker;
    HoneyQueen public honeyQueen;
    Beekeeper public beekeeper;
    
    uint256 public expiration;
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);
    address public constant operator = address(0xaaaa);

    string public constant PROTOCOL = "BGTSTATION";

    // IMPORTANT
    // BARTIO ADDRESSES
    address public constant GOVERNANCE = 0xE3EDa03401Cf32010a9A9967DaBAEe47ed0E1a0b;
    ERC20 public constant HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    IBGTStaker public constant BGT_STAKER = IBGTStaker(0x791fb53432eED7e2fbE4cf8526ab6feeA604Eb6d);
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(1749904));
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        // prettier-ignore
        honeyQueen.setProtocolOfTarget(address(HONEYBERA_STAKING), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdraw(uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);
        honeyQueen.setValidator(THJ);
        factory = new LockerFactory(address(honeyQueen));
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");
    }

    function mintBGT(address _to, uint256 _amount) public {
        vm.startPrank(IBGT(address(BGT)).minter());
        IBGT(address(BGT)).mint(_to, _amount);
        vm.stopPrank();
        vm.startPrank(THJ);
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_initializeOnlyOnce() external prankAsTHJ {
        vm.expectRevert();
        honeyLocker.initialize(THJ, address(honeyQueen), referral, false);
    }

    function test_singleDepositAndLock() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);

        vm.expectEmit(true, true, false, false, address(honeyLocker));
        emit HoneyLocker.Deposited(address(HONEYBERA_LP), balance);
        vm.expectEmit(true, false, false, false, address(honeyLocker));
        emit HoneyLocker.LockedUntil(address(HONEYBERA_LP), expiration);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        assertEq(HONEYBERA_LP.balanceOf(address(honeyLocker)), balance);
    }

    function test_multipleDeposits() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        // prettier-ignore
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration);

        // cannot deposit with a different expiration
        vm.expectRevert(HoneyLocker.ExpirationNotMatching.selector);
        // prettier-ignore
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration - 1);

        // deposit
        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Deposited(address(HONEYBERA_LP), balance / 2);
        emit HoneyLocker.LockedUntil(address(HONEYBERA_LP), expiration);
        // prettier-ignore
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance / 2, expiration);
    }

    function test_stakeAndUnstake() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        vm.expectEmit(true, true, false, true, address(honeyLocker));
        // prettier-ignore
        emit HoneyLocker.Staked(address(HONEYBERA_STAKING), address(HONEYBERA_LP), balance);
        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );
        assertEq(HONEYBERA_LP.balanceOf(THJ), 0, "post-stake balance should be O");

        vm.expectEmit(true, true, false, true, address(honeyLocker));
        emit HoneyLocker.Unstaked(address(HONEYBERA_STAKING), address(HONEYBERA_LP), balance);
        honeyLocker.unstake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("withdraw(uint256)", balance)
        );
        assertEq(
            HONEYBERA_LP.balanceOf(address(honeyLocker)),
            balance,
            "post-unstake balance should be equal to initial balance"
        );
    }

    function test_claimRewards() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        uint256 bgtBalanceBefore = BGT.balanceOf(address(honeyLocker));
        // deal some BGT
        StdCheats.deal(address(BGT), address(honeyLocker), 1);
        honeyLocker.claimRewards(
            address(HONEYBERA_STAKING), abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );
        // balance should have increased!
        uint256 bgtBalanceAfter = BGT.balanceOf(address(honeyLocker));
        // prettier-ignore
        assertTrue(bgtBalanceAfter > bgtBalanceBefore, "BGT balance did not increase!");
    }

    function test_claimRewardsWithAutomaton() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        uint256 bgtBalanceBefore = BGT.balanceOf(address(honeyLocker));
        // deal some BGT
        StdCheats.deal(address(BGT), address(honeyLocker), 1);
        honeyLocker.setOperator(operator);
        vm.startPrank(operator);
        honeyLocker.claimRewards(
            address(HONEYBERA_STAKING), abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );
        vm.stopPrank();
        // balance should have increased!
        uint256 bgtBalanceAfter = BGT.balanceOf(address(honeyLocker));
        // prettier-ignore
        assertTrue(bgtBalanceAfter > bgtBalanceBefore, "BGT balance did not increase!");
    }

    function test_burnBGTForBERA() external prankAsTHJ {
        // deposit, get some rewards
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);
        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        uint256 amountOfBGT = 10e18;
        mintBGT(address(honeyLocker), amountOfBGT);

        honeyLocker.claimRewards(
            address(HONEYBERA_STAKING), abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );

        // time to burn
        uint256 beraBalanceBefore = address(THJ).balance;
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.Redeem(address(honeyLocker), address(honeyLocker), amountOfBGT);
        honeyLocker.burnBGTForBERA(amountOfBGT);
        uint256 beraBalanceAfter = address(THJ).balance;
        // prettier-ignore
        assertTrue(beraBalanceAfter > beraBalanceBefore, "BERA balance did not increase!");
    }

    function test_withdrawLPToken() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        // cannot withdraw too early
        vm.expectRevert(HoneyLocker.NotExpiredYet.selector);
        honeyLocker.withdrawLPToken(address(HONEYBERA_LP), balance);
        // move forward in time
        vm.warp(expiration + 1);
        // should be able to withdraw
        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(HONEYBERA_LP), balance);
        honeyLocker.withdrawLPToken(address(HONEYBERA_LP), balance);
    }

    function test_cannotWithdrawNFT() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        GaugeAsNFT gauge = new GaugeAsNFT(address(HONEYBERA_LP));
        honeyQueen.setProtocolOfTarget(address(gauge), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyLocker.stake(
            address(HONEYBERA_LP), address(gauge), balance, abi.encodeWithSignature("stake(uint256)", balance)
        );
        // block the nft from being transfered
        honeyQueen.setIsTokenBlocked(address(gauge), true);
        // should fail
        vm.expectRevert(HoneyLocker.TokenBlocked.selector);
        honeyLocker.withdrawERC721(address(gauge), 0);
    }

    function test_migration() external prankAsTHJ {
        // deposit first some into contract
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        // clone it
        HoneyLockerV2 honeyLockerV2 = new HoneyLockerV2();
        honeyLockerV2.initialize(THJ, address(honeyQueen), referral, false);
        honeyLockerV2.setMigratingVault(address(honeyLocker));

        // migration should fail because haven't set it in honey queen
        vm.expectRevert(HoneyLocker.MigrationNotEnabled.selector);
        honeyLocker.migrate(SLA.addresses(address(HONEYBERA_LP)), SLA.uint256s(balance), payable(address(honeyLockerV2)));

        // set hashcode in honeyqueen then attempt migration
        honeyQueen.setMigrationFlag(true, address(honeyLocker).codehash, address(honeyLockerV2).codehash);
        vm.expectEmit(true, false, false, false, address(honeyLockerV2));
        //using honeyLocker V1 to emit because for some reasons can't
        // access the event in V2
        emit HoneyLocker.Deposited(address(HONEYBERA_LP), balance);
        vm.expectEmit(true, false, false, false, address(honeyLockerV2));
        emit HoneyLocker.LockedUntil(address(HONEYBERA_LP), expiration);
        vm.expectEmit(true, true, true, false, address(honeyLocker));
        emit HoneyLocker.Migrated(address(HONEYBERA_LP), address(honeyLocker), address(honeyLockerV2));
        honeyLocker.migrate(SLA.addresses(address(HONEYBERA_LP)), SLA.uint256s(balance), payable(address(honeyLockerV2)));
        assertEq(HONEYBERA_LP.balanceOf(address(honeyLockerV2)), balance);
    }

    function test_cannotCheatSelector() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, uint256(1));

        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(HONEYBERA_STAKING),
            balance,
            abi.encodeWithSignature("stake(uint256)", balance)
        );

        vm.expectRevert(HoneyLocker.SelectorNotAllowed.selector);
        honeyLocker.claimRewards(address(HONEYBERA_STAKING), abi.encodeWithSignature("withdraw(uint256)", balance));
    }
}
