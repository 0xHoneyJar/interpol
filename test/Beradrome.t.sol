// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {BeradromeAdapter, IBeradromeGauge} from "../src/adapters/BeradromeAdapter.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {Constants} from "../src/Constants.sol";

contract BeradromeTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    BeradromeAdapter    public adapter;
    BVA                 public lockerAdapter;


    // Beradrome Bex PAW-HONEY PLUGIN for deposits and withdrawals
    address public constant PLUGIN          = 0xF89F4fdE1Bf970404160eD7B9F4758B0b1ae266D;
    // Beradrome Bex PAW-HONEY Gauge for rewards
    address public constant GAUGE           = 0x3fE3030005C11C17146Ea11F4c51406a9a77442A;
    //  Bex PAW-HONEY LP token  
    ERC20   public constant LP_TOKEN        = ERC20(0xa51afAF359d044F8e56fE74B9575f23142cD4B76);
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));
        super.setUp();

        adapter = new BeradromeAdapter();

        vm.startPrank(THJ);

        queen.setAdapterForProtocol("BERADROME", address(adapter));
        queen.setVaultForProtocol("BERADROME", PLUGIN, address(LP_TOKEN), true);
        locker.registerVault(PLUGIN, false);

        lockerAdapter = BVA(locker.vaultToAdapter(PLUGIN));

        vm.stopPrank();

        vm.label(address(lockerAdapter), "BeradromeAdapter");
        vm.label(address(PLUGIN), "Beradrome Bex PAW-HONEY PLUGIN");
        vm.label(address(GAUGE), "Beradrome Bex PAW-HONEY GAUGE");
        vm.label(address(LP_TOKEN), "Bex PAW-HONEY LP Token");
    }
    /*###############################################################
                            TESTS
    ###############################################################*/
    function test_staking(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amount);

        locker.stake(address(PLUGIN), amount);

        assertEq(LP_TOKEN.balanceOf(address(locker)), 0);
    }


    function test_unstaking(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amount);

        locker.stake(address(PLUGIN), amount);

        locker.unstake(address(PLUGIN), amount);

        assertEq(LP_TOKEN.balanceOf(address(locker)), amount);
    }

    /*
        Given how Beradrome separates the rewards claim from the staking and unstaking contract,
        and that the adapter is the one getting the rewards, we have to ensure that all rewards
        claimed are directly transfered to the locker and aren't kept in the adapter.
    */
    function test_claimRewards(uint64 _amount, bool useOperator) external prankAsTHJ(useOperator) {
        address user = useOperator ? operator : THJ;
        uint256 amount = StdUtils.bound(uint256(_amount), 1e18, type(uint64).max);

        StdCheats.deal(address(LP_TOKEN), address(locker), amount);

        locker.stake(address(PLUGIN), amount);

        // Simulate some time passing to accrue rewards
        vm.warp(block.timestamp + 7 days);

        (address[] memory rewardTokens, uint256[] memory earned) = lockerAdapter.earned();

        for (uint256 i; i < rewardTokens.length; i++) {
            vm.expectEmit(true, true, false, true, address(locker));
            emit HoneyLocker.Claimed(address(PLUGIN), rewardTokens[i], earned[i]);
        }

        locker.claim(address(PLUGIN));

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            assertEq(ERC20(rewardTokens[i]).balanceOf(address(locker)), earned[i]);
        }
    }
}