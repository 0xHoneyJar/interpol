// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {KodiakAdapter, IKodiakFarm, XKDK} from "../src/adapters/KodiakAdapter.sol";
import {KodiakAdapterOld} from "./mocks/KodiakAdapterOld.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {Constants} from "../src/Constants.sol";



contract KodiakTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    KodiakAdapterOld    public oldAdapter;
    KodiakAdapter       public newAdapter;
    BVA                 public lockerAdapter;
    ERC20               public constant KDK             = ERC20(0xfd27998fa0eaB1A6372Db14Afd4bF7c4a58C5364);
    XKDK                public constant xKDK            = XKDK(0x414B50157a5697F14e91417C5275A7496DcF429D);
    ERC20               public constant LP_TOKEN        = ERC20(0xE5A2ab5D2fb268E5fF43A5564e44c3309609aFF9); // YEET-WBERA
    IKodiakFarm         public constant GAUGE           = IKodiakFarm(0xbdEE3F788a5efDdA1FcFe6bfe7DbbDa5690179e6);
    ERC721              public constant KODIAKV3        = ERC721(0xC0568C6E9D5404124c8AA9EfD955F3f14C8e64A6);
    
    uint256             public NFT_ID;
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));

        super.setUp();

        // Deploy adapter implementation that will be cloned
        oldAdapter = new KodiakAdapterOld();
        newAdapter = new KodiakAdapter();

        vm.startPrank(THJ);

        queen.setUpgradeOf(address(oldAdapter), address(newAdapter));

        queen.setAdapterApproval(address(GAUGE), address(oldAdapter), true);
        queen.setVaultAdapter(address(GAUGE), address(oldAdapter), address(LP_TOKEN));
        locker.registerVault(address(GAUGE), false);

        lockerAdapter = BVA(locker.vaultToAdapter(address(GAUGE)));

        vm.stopPrank();

        vm.label(address(oldAdapter), "KodiakAdapterOld");
        vm.label(address(newAdapter), "KodiakAdapter");
        vm.label(address(lockerAdapter), "LockerAdapter");
        vm.label(address(GAUGE), "Kodiak Gauge");
        vm.label(address(LP_TOKEN), "Kodiak LP Token");
        vm.label(address(KODIAKV3), "KodiakV3");
        vm.label(address(xKDK), "XKDK");
        vm.label(address(KDK), "KDK");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/
    /*
        We want to test if upgrading from the old adapter to the new one
        preserves not only the state of the adapter wrt Kodiak vault but also
        allows us to add functionalities such as redeeming xKDK
    */
    function test_upgradeWithSimpleUnstake(uint128 _amountToDeposit) public prankAsTHJ(false) {
        uint256 amountToDeposit = StdUtils.bound(uint256(_amountToDeposit), 1e20, type(uint128).max);
        
        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(lockerAdapter), block.timestamp, amountToDeposit, GAUGE.lockedLiquidityOf(address(lockerAdapter))
            )
        );
        locker.stake(address(GAUGE), amountToDeposit);

        // now we upgrade
        locker.upgradeAdapter(address(GAUGE));

        vm.warp(block.timestamp + 30 days);
        GAUGE.sync();

        // now we unstake and see if we get our stake back
        locker.unstake(address(GAUGE), uint256(expectedKekId));
        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit);
    }

    function test_upgradeWithXKDKRedeem(uint128 _amountToDeposit) public prankAsTHJ(false) {
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

        // now we unstake and see if we get our stake back
        locker.unstake(address(GAUGE), uint256(expectedKekId));
        assertEq(LP_TOKEN.balanceOf(address(locker)), amountToDeposit);

        uint256 xkdkBalance = xKDK.balanceOf(address(lockerAdapter));
        uint256 kdkBalance = KDK.balanceOf(address(lockerAdapter));

        // now we redeem xKDK but expect failure
        vm.expectRevert(BVA.BaseVaultAdapter__NotImplemented.selector);
        locker.wildcard(address(GAUGE), 0, abi.encode(xkdkBalance, 15 days));

        // now we upgrade
        locker.upgradeAdapter(address(GAUGE));

        // xKDK balance should have NOT changed
        assertEq(xKDK.balanceOf(address(lockerAdapter)), xkdkBalance);

        // now we redeem xKDK
        locker.wildcard(address(GAUGE), 0, abi.encode(xkdkBalance, 15 days));

        vm.warp(block.timestamp + 15 days);

        // finalize the redeem
        locker.wildcard(address(GAUGE), 1, abi.encode(0));

        assertEq(KDK.balanceOf(address(locker)), kdkBalance + (xkdkBalance / 2));
    }
}

