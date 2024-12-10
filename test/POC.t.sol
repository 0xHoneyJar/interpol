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
import {IBGT} from "./interfaces/IBGT.sol";

interface XKDK {
    function redeem(uint256 amount, uint256 duration) external;
    function finalizeRedeem(uint256 redeemIndex) external;

    function rewardsAddress() external returns (address);
}

interface KodiakRewards {
    struct UserInfo {
        uint256 pendingRewards;
        uint256 rewardDebt;
    }
    function users(
        address user,
        address distributedToken
    ) external returns (UserInfo memory userInfo);
    function distributedTokensLength() external returns (uint256);
    function distributedToken(uint256 index) external returns (address);

    function harvestRewards(address token) external;
    function harvestAllRewards() external;
}

// prettier-ignore
contract POCTest is Test {
    using LibString for uint256;

    LockerFactory public factory;
    HoneyLocker public honeyLocker;
    HoneyQueen public honeyQueen;
    Beekeeper public beekeeper;
    
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);
    address public constant operator = address(0xaaaa);

    string public constant PROTOCOL = "BGTSTATION";

    // These addresses are for the BARTIO network
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    ERC20 public constant weHONEY_LP = ERC20(0x556b758AcCe5c4F2E1B57821E2dd797711E790F4);
    IStakingContract public weHONEY_GAUGE = IStakingContract(0x86DA232f6A4d146151755Ccf3e4555eadCc24cCF);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint(7892764));

        vm.startPrank(THJ);

        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);

        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        // prettier-ignore
        honeyQueen.setProtocolOfTarget(address(weHONEY_GAUGE), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdraw(uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);
        honeyQueen.setValidator(THJ);

        factory = new LockerFactory(address(honeyQueen));
        
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        honeyLocker.setOperator(operator);

        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(weHONEY_LP), "weHONEY_LP");
        vm.label(address(weHONEY_GAUGE), "weHONEY_GAUGE");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");


        // ---> EDIT IF NEEDED <---
        // Deal yourself LP tokens
        StdCheats.deal(address(weHONEY_LP), THJ, 1);

    }

    function test_POC() external {
        vm.startPrank(THJ);
        string memory xkdkProtocol = "XKDK";
        string memory xkdkRewardProtocol = "XKDK-Reward";
        XKDK xKDK = XKDK(address(0x414B50157a5697F14e91417C5275A7496DcF429D));
        ERC20 KDK = ERC20(0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364);
        // whitelist xkdk
        honeyQueen.setProtocolOfTarget(address(xKDK), xkdkProtocol);
        honeyQueen.setProtocolOfTarget(xKDK.rewardsAddress(), xkdkRewardProtocol);

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

        // start the redeem for 180 days (for 1x multipier or 15 days for 0.5x amount)
        honeyLocker.wildcard(
            address(xKDK), abi.encodeWithSelector(bytes4(keccak256("redeem(uint256,uint256)")), xkdkBalance, 180 days)
        );

        // ff 180 days
        vm.warp(block.timestamp + 180 days);

        // finalize the redeem
        uint256 expectedBalance = xkdkBalance;
        honeyLocker.wildcard(address(xKDK), abi.encodeWithSelector(bytes4(keccak256("finalizeRedeem(uint256)")), 0));
        assertEq(KDK.balanceOf(address(honeyLocker)), expectedBalance);

        // the allocated distributed rewards that has not been harvest
        // console.log("KodiakRewards - Distributed tokens and allocation for HoneyLocker");
        KodiakRewards kodiakRewards = KodiakRewards(xKDK.rewardsAddress());
        for (uint256 i; i<kodiakRewards.distributedTokensLength(); i++) {
            address distributedToken = kodiakRewards.distributedToken(i);
            console.log("Distributed tokens: %s ", distributedToken);
            KodiakRewards.UserInfo memory userInfo = kodiakRewards.users(distributedToken, address(honeyLocker));
            console.log("userInfo.pendingRewards: %s ", userInfo.pendingRewards);
            console.log("userInfo.rewardsDebt: %s \n", userInfo.rewardDebt);
        }

        honeyQueen.setIsSelectorAllowedForProtocol(
            bytes4(keccak256("harvestAllRewards()")), "wildcard", xkdkRewardProtocol, true
        );

        honeyLocker.wildcard(xKDK.rewardsAddress(), abi.encodeWithSelector(bytes4(keccak256("harvestAllRewards()"))));

        // Print balances of all distributed tokens for honeyLocker
        for (uint256 i; i < kodiakRewards.distributedTokensLength(); i++) {
            address distributedToken = kodiakRewards.distributedToken(i);
            ERC20 token = ERC20(distributedToken);
            uint256 balance = token.balanceOf(address(honeyLocker));
            console.log("HoneyLocker balance of %s: %s", distributedToken, balance);
        }
    }

}
