// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Factory} from "../src/Factory.sol";

interface KodiakStaking {
    function stakeLocked(uint256 amount, uint256 secs) external;
    function withdrawLockedAll() external;
    function getReward() external view returns (uint256);
    function lockedLiquidityOf(address account) external view returns (uint256);

    event StakeLocked(address indexed user, uint256 amount, uint256 secs, bytes32 kek_id, address source_address);
    event WithdrawLocked(address indexed user, uint256 amount, bytes32 kek_id, address destination_address);
    event RewardPaid(address indexed user, uint256 reward, address token_address, address destination_address);
}

interface XKDK {
    function redeem(uint256 amount, uint256 duration) external;
    function finalizeRedeem(uint256 redeemIndex) external;
}
// prettier-ignore

contract KodiakTest is Test {
    using LibString for uint256;

    Factory public factory;
    HoneyLocker public honeyLocker;
    HoneyQueen public honeyQueen;

    uint256 public expiration;
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);
    string public constant PROTOCOL = "KODIAK";

    // IMPORTANT
    // BARTIO ADDRESSES
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    ERC20 public constant KDK = ERC20(0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364);
    XKDK public constant xKDK = XKDK(0x414B50157a5697F14e91417C5275A7496DcF429D);
    ERC20 public constant HONEYBERA_LP = ERC20(0x12C195768f65F282EA5F1B5C42755FBc910B0D8F);
    KodiakStaking public constant KODIAK_STAKING = KodiakStaking(0x1878eb1cA6Da5e2fC4B5213F7D170CA668A0E225);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(1791773));
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury, address(BGT));
        // prettier-ignore
        honeyQueen.setProtocolOfTarget(address(KODIAK_STAKING), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(
            bytes4(keccak256("stakeLocked(uint256,uint256)")), "stake", PROTOCOL, true
        );
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdrawLockedAll()")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward()")), "rewards", PROTOCOL, true);
        honeyQueen.setValidator(THJ);

        factory = new Factory(address(honeyQueen));

        honeyLocker = factory.clone(THJ, referral, false);

        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(KODIAK_STAKING), "KODIAK_STAKING");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_stake() external prankAsTHJ {
        // deposit the LP tokens first
        uint256 LPBalance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), LPBalance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), LPBalance, expiration);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(honeyLocker), block.timestamp, LPBalance, KODIAK_STAKING.lockedLiquidityOf(address(honeyLocker))
            )
        );

        // add extra expects?
        vm.expectEmit(true, false, false, true, address(KODIAK_STAKING));
        emit KodiakStaking.StakeLocked(address(honeyLocker), LPBalance, 30 days, expectedKekId, address(honeyLocker));
        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), LPBalance, 30 days)
        );
    }

    function test_unstakeSingle() external prankAsTHJ {
        uint256 LPBalance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), LPBalance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), LPBalance, expiration);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(honeyLocker), block.timestamp, LPBalance, KODIAK_STAKING.lockedLiquidityOf(address(honeyLocker))
            )
        );

        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), LPBalance, 30 days)
        );

        uint256 kdkBalanceBefore = KDK.balanceOf(address(honeyLocker));
        // go forward 30 days
        vm.warp(block.timestamp + 30 days);
        vm.expectEmit(true, false, false, true, address(KODIAK_STAKING));
        emit KodiakStaking.WithdrawLocked(address(honeyLocker), LPBalance, expectedKekId, address(honeyLocker));
        honeyLocker.unstake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("withdrawLockedAll()")))
        );

        // kdk balance of locker should have gone UP
        uint256 kdkBalanceAfter = KDK.balanceOf(address(honeyLocker));
        assertGt(kdkBalanceAfter, kdkBalanceBefore);
    }

    function test_claimRewards() external prankAsTHJ {
        uint256 LPBalance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), LPBalance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), LPBalance, expiration);

        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), LPBalance, 30 days)
        );

        uint256 kdkBalanceBefore = KDK.balanceOf(address(honeyLocker));
        // go forward 30 days
        vm.warp(block.timestamp + 30 days);

        honeyLocker.claimRewards(address(KODIAK_STAKING), abi.encodeWithSelector(bytes4(keccak256("getReward()"))));
        // kdk balance of locker should have gone UP
        uint256 kdkBalanceAfter = KDK.balanceOf(address(honeyLocker));
        assertGt(kdkBalanceAfter, kdkBalanceBefore);
    }

    function test_multipleStakes() external prankAsTHJ {
        uint256 LPBalance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), LPBalance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), LPBalance, expiration);

        bytes32 expectedKekId0 = keccak256(
            abi.encodePacked(
                address(honeyLocker),
                block.timestamp,
                LPBalance / 2,
                KODIAK_STAKING.lockedLiquidityOf(address(honeyLocker))
            )
        );

        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), LPBalance / 2, 30 days)
        );

        // move forward 15 days
        vm.warp(block.timestamp + 15 days);
        // stake the rest
        bytes32 expectedKekId1 = keccak256(
            abi.encodePacked(
                address(honeyLocker),
                block.timestamp,
                LPBalance / 2,
                KODIAK_STAKING.lockedLiquidityOf(address(honeyLocker))
            )
        );

        honeyLocker.stake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), LPBalance / 2, 30 days)
        );

        // move again 15 days
        vm.warp(block.timestamp + 15 days);

        // should only be able to withdraw HALF as expected
        vm.expectEmit(true, false, false, true, address(KODIAK_STAKING));
        emit KodiakStaking.WithdrawLocked(address(honeyLocker), LPBalance / 2, expectedKekId0, address(honeyLocker));
        honeyLocker.unstake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance / 2,
            abi.encodeWithSelector(bytes4(keccak256("withdrawLockedAll()")))
        );

        // check LP balance of locker
        assertApproxEqRel(HONEYBERA_LP.balanceOf(address(honeyLocker)), LPBalance / 2, 1e14); // 1e14 == 0.01%

        // 15 days later again for the rest
        vm.warp(block.timestamp + 15 days);
        // should only be able to withdraw HALF as expected
        vm.expectEmit(true, false, false, true, address(KODIAK_STAKING));
        emit KodiakStaking.WithdrawLocked(address(honeyLocker), LPBalance / 2, expectedKekId1, address(honeyLocker));
        honeyLocker.unstake(
            address(HONEYBERA_LP),
            address(KODIAK_STAKING),
            LPBalance / 2,
            abi.encodeWithSelector(bytes4(keccak256("withdrawLockedAll()")))
        );

        // check LP balance of locker
        assertApproxEqRel(HONEYBERA_LP.balanceOf(address(honeyLocker)), LPBalance, 1e14);
    }

    function test_xkdk() external prankAsTHJ {
        string memory xkdkProtocol = "XKDK";
        // whitelist xkdk
        honeyQueen.setProtocolOfTarget(address(xKDK), xkdkProtocol);

        // whitelist selectors
        honeyQueen.setIsSelectorAllowedForProtocol(
            bytes4(keccak256("redeem(uint256,uint256)")), "wildcard", xkdkProtocol, true
        );
        honeyQueen.setIsSelectorAllowedForProtocol(
            bytes4(keccak256("finalizeRedeem(uint256)")), "wildcard", xkdkProtocol, true
        );

        ERC20 XKDK_ERC20 = ERC20(address(xKDK));
        uint256 xkdkBalance = 1e18;
        uint256 kdkBalance = KDK.balanceOf(address(honeyLocker));
        StdCheats.deal(address(XKDK_ERC20), address(honeyLocker), xkdkBalance);
        uint256 XKDK_balance = XKDK_ERC20.balanceOf(address(honeyLocker));

        // start the redeem for 15 days so 0.5x multiplier
        honeyLocker.wildcard(
            address(xKDK), abi.encodeWithSelector(bytes4(keccak256("redeem(uint256,uint256)")), xkdkBalance, 15 days)
        );

        // ff 15 days
        vm.warp(block.timestamp + 15 days);

        // finalize the redeem
        honeyLocker.wildcard(address(xKDK), abi.encodeWithSelector(bytes4(keccak256("finalizeRedeem(uint256)")), 0));

        uint256 expectedBalance = kdkBalance + (xkdkBalance / 2);
        assertEq(KDK.balanceOf(address(honeyLocker)), expectedBalance);
    }
}
