// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {BaseTest} from "./Base.t.sol";

interface IBeradromePlugin {
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
}

interface IBeradromeGauge {
    function getReward(address account) external;
    function getRewardTokens() external view returns (address[] memory);
    function earned(address account, address _rewardsToken) external view returns (uint256);
}

contract BeradromeTest is BaseTest {
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    // Beradrome Bex PAW-HONEY PLUGIN for deposits and withdrawals
    address public constant PLUGIN = 0xF89F4fdE1Bf970404160eD7B9F4758B0b1ae266D;
    // Beradrome Bex PAW-HONEY Gauge for rewards
    address public constant GAUGE = 0x3fE3030005C11C17146Ea11F4c51406a9a77442A;
    //  Bex PAW-HONEY LP token  
    ERC20 public constant LP_TOKEN = ERC20(0xa51afAF359d044F8e56fE74B9575f23142cD4B76);

    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        PROTOCOL = "BERADROME";
        
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(7993729));

        super.setUp();

        vm.startPrank(THJ);

        honeyQueen.setProtocolOfTarget(address(GAUGE), PROTOCOL);
        honeyQueen.setProtocolOfTarget(address(PLUGIN), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("depositFor(address,uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdrawTo(address,uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);

        vm.stopPrank();

        vm.label(address(GAUGE), "PAW-HONEYGauge");
        vm.label(address(PLUGIN), "PAW-HONEY Plugin");
        vm.label(address(LP_TOKEN), "PAW-HONEY LP Token");
    }

    function test_staking(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(honeyLocker), amount);

        honeyLocker.stake(
            address(LP_TOKEN),
            address(PLUGIN),
            amount,
            abi.encodeWithSelector(bytes4(keccak256("depositFor(address,uint256)")), address(honeyLocker), amount)
        );

        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), 0);
    }

    function test_unstaking(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(honeyLocker), amount);

        honeyLocker.stake(
            address(LP_TOKEN),
            address(PLUGIN),
            amount,
            abi.encodeWithSelector(bytes4(keccak256("depositFor(address,uint256)")), address(honeyLocker), amount)
        );

        honeyLocker.unstake(
            address(LP_TOKEN),
            address(PLUGIN),
            amount,
            abi.encodeWithSelector(bytes4(keccak256("withdrawTo(address,uint256)")), address(honeyLocker), amount)
        );

        assertEq(LP_TOKEN.balanceOf(address(honeyLocker)), amount);
    }

    function test_claimRewards(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(honeyLocker), amount);

        honeyLocker.stake(
            address(LP_TOKEN),
            address(PLUGIN),
            amount,
            abi.encodeWithSelector(bytes4(keccak256("depositFor(address,uint256)")), address(honeyLocker), amount)
        );

        // Simulate some time passing to accrue rewards
        vm.warp(block.timestamp + 7 days);

        address[] memory rewardTokens = IBeradromeGauge(GAUGE).getRewardTokens();
        uint256[] memory earned = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            earned[i] = IBeradromeGauge(GAUGE).earned(address(honeyLocker), rewardTokens[i]);
        }

        honeyLocker.claimRewards(address(GAUGE), abi.encodeWithSelector(bytes4(keccak256("getReward(address)")), address(honeyLocker)));

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(ERC20(rewardTokens[i]).balanceOf(address(honeyLocker)), earned[i]);
        }
    }
}
