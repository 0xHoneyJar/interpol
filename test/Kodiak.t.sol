// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";

interface KodiakFarm {
    function stakeLocked(uint256 amount, uint256 secs) external;
    function withdrawLocked(bytes32 kekId) external;
    function getReward() external returns (uint256[] memory);
    function getAllRewardTokens() external view returns (address[] memory);
    function lockedLiquidityOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256[] memory);
    function sync() external;

    event StakeLocked(
        address indexed user,
        uint256 amount,
        uint256 secs,
        bytes32 kek_id,
        address source_address
    );
    event WithdrawLocked(
        address indexed user,
        uint256 amount,
        bytes32 kek_id,
        address destination_address
    );
    event RewardPaid(
        address indexed user,
        uint256 reward,
        address token_address,
        address destination_address
    );
}

interface XKDK {
    function redeem(uint256 amount, uint256 duration) external;
    function finalizeRedeem(uint256 redeemIndex) external;
    function balanceOf(address account) external view returns (uint256);
}

/*
    There are currently no "real" Kodiak gauges using KodiakV3
    so we have to use a bogus one.
*/
contract KodiakV3Gauge {
    ERC721 kodiakv3;
    constructor(address _kodiakV3) {
        kodiakv3 = ERC721(_kodiakV3);
    }
    function stake(uint256 _tokenId) external {
        console.log("here");
        kodiakv3.transferFrom(msg.sender, address(this), _tokenId);
    }
    function unstake(uint _tokenId) external {
        kodiakv3.transferFrom(address(this), msg.sender, _tokenId);
    }
}

// prettier-ignore
contract KodiakTest is BaseTest {
    using LibString for uint256;

    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    ERC20           public constant KDK             = ERC20(0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364);
    XKDK            public constant xKDK            = XKDK(0x414B50157a5697F14e91417C5275A7496DcF429D);
    ERC20           public constant LP_TOKEN        = ERC20(0xE5A2ab5D2fb268E5fF43A5564e44c3309609aFF9); // YEET-WBERA
    KodiakFarm      public constant GAUGE           = KodiakFarm(0xbdEE3F788a5efDdA1FcFe6bfe7DbbDa5690179e6);
    ERC721          public constant KODIAKV3        = ERC721(0xC0568C6E9D5404124c8AA9EfD955F3f14C8e64A6);
    KodiakV3Gauge   public kodiakV3Gauge;
    
    uint256         public NFT_ID;

    function setUp() public override {
        PROTOCOL = "KODIAK";

        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(7925685));

        super.setUp();

        kodiakV3Gauge = new KodiakV3Gauge(address(KODIAKV3));

        vm.startPrank(THJ);

        honeyQueen.setProtocolOfTarget(address(GAUGE), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(
            bytes4(keccak256("stakeLocked(uint256,uint256)")), "stake", PROTOCOL, true
        );
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdrawLocked(bytes32)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward()")), "rewards", PROTOCOL, true);

        honeyQueen.setProtocolOfTarget(address(kodiakV3Gauge), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("unstake(uint256)")), "unstake", PROTOCOL, true);

        honeyQueen.setProtocolOfTarget(address(xKDK), "XKDK");
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("redeem(uint256,uint256)")), "wildcard", "XKDK", true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("finalizeRedeem(uint256)")), "wildcard", "XKDK", true);

        vm.stopPrank();

        vm.label(address(LP_TOKEN), "LP_TOKEN");
        vm.label(address(GAUGE), "GAUGE");
        vm.label(address(KODIAKV3), "KODIAK-V3");
        vm.label(address(kodiakV3Gauge), "KodiakV3Gauge");
        vm.label(address(xKDK), "XKDK");
        vm.label(address(KDK), "KDK");
    }

    function test_stake(
        uint32 _amountToDeposit,
        uint128 _expiration,
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        address user = _useOperator ? operator : THJ;
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1, type(uint32).max);
        
        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(_expiration));

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(honeyLocker), block.timestamp, amountToDeposit, GAUGE.lockedLiquidityOf(address(honeyLocker))
            )
        );

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit KodiakFarm.StakeLocked(address(honeyLocker), amountToDeposit, 30 days, expectedKekId, address(honeyLocker));
        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), amountToDeposit, 30 days)
        );
    }

    function test_unstakeSingle(
        uint128 _amountToDeposit,
        uint128 _expiration,
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        address user = _useOperator ? operator : THJ;
        // too low amount results in the withdrawal failing because of how Kodiak works
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1e20, type(uint128).max);
        
        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(_expiration));

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(honeyLocker), block.timestamp, amountToDeposit, GAUGE.lockedLiquidityOf(address(honeyLocker))
            )
        );

        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), amountToDeposit, 30 days)
        );

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit KodiakFarm.WithdrawLocked(address(honeyLocker), amountToDeposit, expectedKekId, address(honeyLocker));
        honeyLocker.unstake(
            address(LP_TOKEN),
            address(GAUGE), 
            amountToDeposit,
            abi.encodeWithSelector(bytes4(keccak256("withdrawLocked(bytes32)")), expectedKekId)
        );

        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), amountToDeposit);
    }

  function test_claimRewards(
        uint128 _amountToDeposit,
        uint128 _expiration,
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        address user = _useOperator ? operator : THJ;
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1e20, type(uint128).max);
        
        StdCheats.deal(address(LP_TOKEN), user, amountToDeposit);

        LP_TOKEN.approve(address(honeyLocker), amountToDeposit);
        honeyLocker.depositAndLock(address(LP_TOKEN), amountToDeposit, uint256(_expiration));

        honeyLocker.stake(
            address(LP_TOKEN),
            address(GAUGE),
            amountToDeposit,
            abi.encodeWithSelector(bytes4(keccak256("stakeLocked(uint256,uint256)")), amountToDeposit, 30 days)
        );

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        uint256[] memory earned = GAUGE.earned(address(honeyLocker));
        address[] memory rewardTokens = GAUGE.getAllRewardTokens();

        honeyLocker.claimRewards(address(GAUGE), abi.encodeWithSelector(bytes4(keccak256("getReward()"))));
        uint256 xkdkBalance = xKDK.balanceOf(address(honeyLocker));
        for (uint256 i; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 rewardBalanceAfter = ERC20(rewardToken).balanceOf(address(honeyLocker));
            if (rewardToken == address(KDK)) {
                assertEq(earned[i], rewardBalanceAfter + xkdkBalance);
            } else {
                assertEq(rewardBalanceAfter, earned[i]);
            }
        }
    }

    function test_xkdk(uint128 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        uint256 KDKBalanceOfXKDK = KDK.balanceOf(address(xKDK));
        uint256 xkdkBalance = StdUtils.bound(uint256(_amount), 1e20, KDKBalanceOfXKDK);

        StdCheats.deal(address(xKDK), address(honeyLocker), xkdkBalance);

        // start the redeem for 15 days so 0.5x multiplier
        honeyLocker.wildcard(
            address(xKDK), abi.encodeWithSelector(bytes4(keccak256("redeem(uint256,uint256)")), xkdkBalance, 15 days)
        );

        vm.warp(block.timestamp + 15 days);

        // finalize the redeem
        honeyLocker.wildcard(address(xKDK), abi.encodeWithSelector(bytes4(keccak256("finalizeRedeem(uint256)")), 0));

        assertEq(KDK.balanceOf(address(honeyLocker)), xkdkBalance / 2);
    }

    // function test_depositV3() external prankAsTHJ {
    //     uint256 nftId = 6658;

    //     StdCheats.dealERC721(address(KODIAKV3), THJ, nftId);

    //     KODIAKV3.approve(address(honeyLocker), nftId);


    //     vm.expectEmit(true, false, false, true, address(honeyLocker));
    //     emit HoneyLocker.Deposited(address(KODIAKV3), nftId);
    //     vm.expectEmit(true, false, false, true, address(honeyLocker));
    //     emit HoneyLocker.LockedUntil(address(KODIAKV3), expiration);
    //     honeyLocker.depositAndLock(address(KODIAKV3), nftId, expiration);
    // }

    // function test_depositKodiakV3() external prankAsTHJ(){
    //     KODIAKV3.approve(address(honeyLocker), 6658);
    //     vm.expectEmit(true, false, false, true, address(honeyLocker));
    //     emit HoneyLocker.Deposited(address(KODIAKV3), 6658);
    //     vm.expectEmit(true, false, false, true, address(honeyLocker));
    //     emit HoneyLocker.LockedUntil(address(KODIAKV3), expiration);
    //     honeyLocker.depositAndLock(address(KODIAKV3), 6658, expiration);
    // }

    // function test_withdrawKodiakV3() external prankAsTHJ(){
    //     KODIAKV3.approve(address(honeyLocker), 6658);
    //     honeyLocker.depositAndLock(address(KODIAKV3), 6658, 1);

    //     vm.expectEmit(true, false, false, true, address(honeyLocker));
    //     emit HoneyLocker.Withdrawn(address(KODIAKV3), 6658);
    //     honeyLocker.withdrawLPToken(address(KODIAKV3), 6658);
    // }

    // function test_stakingKodiakV3() external prankAsTHJ() {
    //     KODIAKV3.approve(address(honeyLocker), 6658);
    //     honeyLocker.depositAndLock(address(KODIAKV3), 6658, expiration);

    //     honeyLocker.stake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("stake(uint256)")), 6658)
    //     );
    // }

    // function test_unstakingKodiakV3() external prankAsTHJ() {
    //     KODIAKV3.approve(address(honeyLocker), 6658);
    //     honeyLocker.depositAndLock(address(KODIAKV3), 6658, expiration);

    //     honeyLocker.stake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("stake(uint256)")), 6658)
    //     );

    //     honeyLocker.unstake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("unstake(uint256)")), 6658)
    //     );
    // }
}
