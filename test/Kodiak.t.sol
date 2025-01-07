// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {KodiakAdapter, IKodiakFarm, XKDK} from "../src/adapters/KodiakAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";

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
        kodiakv3.transferFrom(msg.sender, address(this), _tokenId);
    }
    function unstake(uint _tokenId) external {
        kodiakv3.transferFrom(address(this), msg.sender, _tokenId);
    }
}

contract KodiakTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    KodiakAdapter   public          adapter;
    BVA             public          lockerAdapter;
    ERC20           public constant KDK             = ERC20(0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364);
    XKDK            public constant xKDK            = XKDK(0x414B50157a5697F14e91417C5275A7496DcF429D);
    ERC20           public constant LP_TOKEN        = ERC20(0xE5A2ab5D2fb268E5fF43A5564e44c3309609aFF9); // YEET-WBERA
    IKodiakFarm     public constant GAUGE           = IKodiakFarm(0xbdEE3F788a5efDdA1FcFe6bfe7DbbDa5690179e6);
    ERC721          public constant KODIAKV3        = ERC721(0xC0568C6E9D5404124c8AA9EfD955F3f14C8e64A6);
    KodiakV3Gauge   public          kodiakV3Gauge;
    
    uint256         public          NFT_ID;
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));

        super.setUp();

        // Deploy adapter implementation that will be cloned
        address adapterLogic = address(new KodiakAdapter());
        address adapterBeacon = address(new UpgradeableBeacon(adapterLogic, THJ));

        vm.startPrank(THJ);

        queen.setAdapterBeaconForProtocol("KODIAK", address(adapterBeacon));
        queen.setVaultForProtocol("KODIAK", address(GAUGE), address(LP_TOKEN), true);
        locker.registerAdapter("KODIAK");

        lockerAdapter = BVA(locker.adapterOfProtocol("KODIAK"));

        vm.stopPrank();

        vm.label(address(adapter), "KodiakAdapter Logic");
        vm.label(address(lockerAdapter), "KodiakAdapter Locker");
        vm.label(address(GAUGE), "Kodiak Gauge");
        vm.label(address(LP_TOKEN), "Kodiak LP Token");
        vm.label(address(KODIAKV3), "KodiakV3");
        vm.label(address(kodiakV3Gauge), "KodiakV3Gauge");
        vm.label(address(xKDK), "XKDK");
        vm.label(address(KDK), "KDK");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

  function test_stake(uint32 _amountToDeposit, bool _useOperator) external prankAsTHJ(_useOperator) {
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1, type(uint32).max);
        
        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(lockerAdapter), block.timestamp, amountToDeposit, GAUGE.lockedLiquidityOf(address(lockerAdapter))
            )
        );

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IKodiakFarm.StakeLocked(address(lockerAdapter), amountToDeposit, 30 days, expectedKekId, address(lockerAdapter));
        locker.stake(address(GAUGE), amountToDeposit);
    }

    function test_unstakeSingle(
        uint128 _amountToDeposit,
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        // too low amount results in the withdrawal failing because of how Kodiak works
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1e20, type(uint128).max);
        
        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(lockerAdapter), block.timestamp, amountToDeposit, GAUGE.lockedLiquidityOf(address(lockerAdapter))
            )
        );

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        vm.expectEmit(true, false, false, true, address(GAUGE));
        emit IKodiakFarm.WithdrawLocked(address(lockerAdapter), amountToDeposit, expectedKekId, address(lockerAdapter));
        locker.unstake(address(GAUGE), uint256(expectedKekId));

        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit);
    }

    function test_claimRewards(
        uint128 _amountToDeposit,
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1e20, type(uint128).max);
        
        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        (address[] memory rewardTokens, uint256[] memory earned) = lockerAdapter.earned(address(GAUGE));

        // always skip xKDK because it won't be emitted
        for (uint256 i; i < rewardTokens.length - 1; i++) {
            vm.expectEmit(true, true, false, true, address(locker));
            emit HoneyLocker.HoneyLocker__Claimed(address(GAUGE), rewardTokens[i], earned[i]);
        }

        locker.claim(address(GAUGE));
        // skip xKDK testing in the loop, do it separately
        for (uint256 i; i < rewardTokens.length - 1; i++) {
            address rewardToken = rewardTokens[i];
            uint256 rewardBalanceAfter = ERC20(rewardToken).balanceOf(address(locker));
            assertEq(rewardBalanceAfter, earned[i]);
        }
        uint256 xkdkBalance = xKDK.balanceOf(address(lockerAdapter));
        assertEq(xkdkBalance, earned[earned.length - 1]);
    }

    function test_xkdk(uint128 _amount, bool _useOperator) external prankAsTHJ(_useOperator) {
        uint256 KDKBalanceOfXKDK = KDK.balanceOf(address(xKDK));
        uint256 xkdkBalance = StdUtils.bound(uint256(_amount), 1e20, KDKBalanceOfXKDK);

        StdCheats.deal(address(xKDK), address(lockerAdapter), xkdkBalance);

        // start the redeem for 15 days so 0.5x multiplier
        locker.wildcard(address(GAUGE), 0, abi.encode(xkdkBalance, 15 days));

        vm.warp(block.timestamp + 15 days);

        // finalize the redeem
        locker.wildcard(address(GAUGE), 1, abi.encode(0));

        assertEq(KDK.balanceOf(address(locker)), xkdkBalance / 2);
    }

    function test_unstakeDoSShouldFail(
        bool _useOperator
    ) external prankAsTHJ(_useOperator) {
        // too low amount results in the withdrawal failing because of how Kodiak works
        uint256 amountToDeposit = 1000e18;

        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(lockerAdapter),
                block.timestamp,
                amountToDeposit,
                GAUGE.lockedLiquidityOf(address(lockerAdapter))
            )
        );

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        StdCheats.deal(address(LP_TOKEN), address(lockerAdapter), 1);
 
        locker.unstake(address(GAUGE), uint256(expectedKekId));

        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit + 1);
    }

    // function test_depositV3() external prankAsTHJ {
    //     uint256 nftId = 6658;

    //     StdCheats.dealERC721(address(KODIAKV3), THJ, nftId);

    //     KODIAKV3.approve(address(locker), nftId);


    //     vm.expectEmit(true, false, false, true, address(locker));
    //     emit HoneyLocker.HoneyLocker__Deposited(address(KODIAKV3), nftId);
    //     vm.expectEmit(true, false, false, true, address(locker));
    //     emit HoneyLocker.HoneyLocker__LockedUntil(address(KODIAKV3), expiration);
    //     locker.depositAndLock(address(KODIAKV3), nftId, expiration);
    // }

    // function test_depositKodiakV3() external prankAsTHJ(){
    //     KODIAKV3.approve(address(locker), 6658);
    //     vm.expectEmit(true, false, false, true, address(locker));
    //     emit HoneyLocker.HoneyLocker__Deposited(address(KODIAKV3), 6658);
    //     vm.expectEmit(true, false, false, true, address(locker));
    //     emit HoneyLocker.HoneyLocker__LockedUntil(address(KODIAKV3), expiration);
    //     locker.depositAndLock(address(KODIAKV3), 6658, expiration);
    // }

    // function test_withdrawKodiakV3() external prankAsTHJ(){
    //     KODIAKV3.approve(address(locker), 6658);
    //     locker.depositAndLock(address(KODIAKV3), 6658, 1);

    //     vm.expectEmit(true, false, false, true, address(locker));
    //     emit HoneyLocker.HoneyLocker__Withdrawn(address(KODIAKV3), 6658);
    //     locker.withdrawLPToken(address(KODIAKV3), 6658);
    // }

    // function test_stakingKodiakV3() external prankAsTHJ() {
    //     KODIAKV3.approve(address(locker), 6658);
    //     locker.depositAndLock(address(KODIAKV3), 6658, expiration);

    //     locker.stake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("stake(uint256)")), 6658)
    //     );
    // }

    // function test_unstakingKodiakV3() external prankAsTHJ() {
    //     KODIAKV3.approve(address(locker), 6658);
    //     locker.depositAndLock(address(KODIAKV3), 6658, expiration);

    //     locker.stake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("stake(uint256)")), 6658)
    //     );

    //     locker.unstake(
    //         address(KODIAKV3),
    //         address(kodiakV3Gauge),
    //         6658,
    //         abi.encodeWithSelector(bytes4(keccak256("unstake(uint256)")), 6658)
    //     );
    // }
}
