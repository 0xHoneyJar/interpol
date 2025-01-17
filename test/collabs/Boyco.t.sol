// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BaseTest} from "../Base.t.sol";
import {HoneyLocker} from "../../src/HoneyLocker.sol";
import {BGTStationAdapter, IBGTStationGauge} from "../../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../../src/adapters/BaseVaultAdapter.sol";
import {BoycoInterpolVault} from "../../src/collabs/boyco/BoycoInterpolVault.sol";
import {BoycoInterpolVaultV2} from "./BoycoInterpolVaultV2.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract BoycoTest is BaseTest {
    using Math for uint256;
    BGTStationAdapter   public adapter;
    BVA                 public lockerAdapter;   // adapter for BGT Station used by locker

    // BERA-HONEY gauge
    address     public constant GAUGE       = 0x0cc03066a3a06F3AC68D3A0D36610F52f7C20877;
    // BERA-HONEY LP token
    ERC20       public constant LP_TOKEN    = ERC20(0x3aD1699779eF2c5a4600e649484402DFBd3c503C);

    
    /*###############################################################
                            ROYCO PARAMS
    ###############################################################*/
    BoycoInterpolVault  public boycoInterpolVault;

    MockERC20           public asset;
    address             public vault            = GAUGE; 
    bytes               public validatorBytes   = hex"49e7CF782fB697CDAe1046D45778C8aE3D7eC644";
    address             public sfOperator       = makeAddr("sfOperator");

    function setUp() public override {
        vm.createSelectFork(RPC_URL_ALT);

        super.setUp();

        // Deploy adapter implementation that will be cloned
        address adapterLogic = address(new BGTStationAdapter());
        address adapterBeacon = address(new UpgradeableBeacon(adapterLogic, THJ));

        asset = new MockERC20();
        asset.setUse18Decimals(false);

        vm.startPrank(THJ);

        queen.setAdapterBeaconForProtocol("BGTSTATION", address(adapterBeacon));
        queen.setVaultForProtocol("BGTSTATION", GAUGE, address(LP_TOKEN), true);

        lockerAdapter = BVA(locker.adapterOfProtocol("BGTSTATION"));

        // Deploy vault
        address _boycoInterpolVault = Upgrades.deployUUPSProxy(
            "BoycoInterpolVault.sol",
            abi.encodeCall(BoycoInterpolVault.initialize, (THJ, address(locker), address(asset), vault))
        );

        boycoInterpolVault = BoycoInterpolVault(payable(_boycoInterpolVault));

        // Configure vault
        boycoInterpolVault.setValidator(validatorBytes);

        // Configure locker
        HoneyLocker(payable(locker)).setOperator(_boycoInterpolVault);
        HoneyLocker(payable(locker)).registerAdapter("BGTSTATION");
        //HoneyLocker(payable(locker)).wildcard(vault, 0, "");
        HoneyLocker(payable(locker)).transferOwnership(address(sfOperator));

        vm.stopPrank();
    }

    function test_initialization() public {
        assertEq(boycoInterpolVault.validator(), validatorBytes);
        assertEq(boycoInterpolVault.asset(), address(asset));
        assertEq(boycoInterpolVault.vault(), vault);
    }

    function test_deposit() public prankAsTHJ(false) {
        uint256 amount = 1000 * 10**6;
        asset.mint(THJ, amount);

        asset.approve(address(boycoInterpolVault), amount);
        uint256 shares = boycoInterpolVault.deposit(amount, THJ);

        console2.log("Shares: %s", shares);

        assertGt(shares, 0);
        assertEq(asset.balanceOf(THJ), 0);
        assertEq(asset.balanceOf(address(boycoInterpolVault)), 0);
        assertEq(asset.balanceOf(address(locker)), amount);
        assertEq(boycoInterpolVault.balanceOf(THJ), shares);
    }

    function test_operatorSwapAssetForLP() public {
        uint256 amount = 10 ether;
        asset.mint(THJ, amount);

        vm.startPrank(THJ);
        asset.approve(address(boycoInterpolVault), amount);
        uint256 shares = boycoInterpolVault.deposit(amount, THJ);
        vm.stopPrank();

        // operator withdraws assets from the vault to swap them
        // givne the operator is the owner of locker, should withdraw to its address
        vm.startPrank(sfOperator);

        locker.withdrawLPToken(address(asset), amount);
        assertEq(asset.balanceOf(sfOperator), amount);
        // assume some swap for LP tokens which are then deposited and staked
        uint256 LPAmount = 100 ether;
        StdCheats.deal(address(LP_TOKEN), sfOperator, LPAmount);
        LP_TOKEN.approve(address(locker), LPAmount);
        locker.depositAndLock(address(LP_TOKEN), LPAmount, 1);
        locker.stake(vault, LPAmount);

        vm.stopPrank();

        assertEq(locker.totalLPStaked(address(LP_TOKEN)), LPAmount);

    }

    /*
        For redeeming, we assume that the locker holds all staked LP tokens
        and the boyco vault holds the reward tokens.

        Before redeeming, S&F operator (or another address in prod) transfers 
        ownership of the locker to the boyco vault.
    */
    function test_redeem(address[10] memory _depositors, uint256[10] memory _amounts) public {
        uint256 totalDeposited = 0;
        // deposit for all depositors
        for (uint256 i; i < _depositors.length; i++) {
            _depositors[i] = makeAddr(string(abi.encodePacked("depositor", i)));
            _amounts[i] = StdUtils.bound(_amounts[i], 1 ether, type(uint64).max);

            asset.mint(_depositors[i], _amounts[i]);

            vm.startPrank(_depositors[i]);
            asset.approve(address(boycoInterpolVault), _amounts[i]);
            uint256 shares = boycoInterpolVault.deposit(_amounts[i], _depositors[i]);
            vm.stopPrank();

            totalDeposited += _amounts[i];
        }

        // deal LP tokens to locker and have it staked
        uint256 amountToStake = 100 ether;
        StdCheats.deal(address(LP_TOKEN), address(sfOperator), amountToStake);
        vm.startPrank(sfOperator);
        LP_TOKEN.approve(address(locker), amountToStake);
        locker.depositAndLock(address(LP_TOKEN), amountToStake, 1);
        locker.stake(vault, amountToStake);
        vm.stopPrank();
    
        // create a reward token for the vault
        uint256 rewardsToMint = 100 ether;
        MockERC20 rewardToken = new MockERC20();
        vm.prank(THJ);
        boycoInterpolVault.setHenlo(address(rewardToken));
        rewardToken.mint(address(boycoInterpolVault), rewardsToMint);

        // transfer ownership of the locker to the boyco vault
        vm.prank(sfOperator);
        HoneyLocker(payable(locker)).transferOwnership(address(boycoInterpolVault));

        // redeem for one depositor
        uint256 expectedLPToReceive = locker.totalLPStaked(address(LP_TOKEN)).mulDiv(_amounts[0], totalDeposited);
        uint256 expectedRewardToReceive = rewardsToMint.mulDiv(_amounts[0], totalDeposited);
        uint256 sharesToRedeem = boycoInterpolVault.balanceOf(_depositors[0]);
    
        uint256 LPToWithdraw = sharesToRedeem.mulDiv(locker.totalLPStaked(address(LP_TOKEN)) + 1, boycoInterpolVault.totalSupply() + 1, Math.Rounding.Floor);

        vm.prank(_depositors[0]);
        boycoInterpolVault.redeem(sharesToRedeem, _depositors[0]);

        assertEq(boycoInterpolVault.balanceOf(_depositors[0]), 0);
        assertApproxEqRel(locker.totalLPStaked(address(LP_TOKEN)), amountToStake - expectedLPToReceive, 1e14); // 1e14 is 0.01%
        assertApproxEqRel(rewardToken.balanceOf(_depositors[0]), expectedRewardToReceive, 1e14);


        // continue to redeem for the rest
        for (uint256 i = 1; i < _depositors.length; i++) {
            uint256 sharesToRedeem = boycoInterpolVault.balanceOf(_depositors[i]);
            vm.prank(_depositors[i]);
            boycoInterpolVault.redeem(sharesToRedeem, _depositors[i]);
        }

        assertLe(locker.totalLPStaked(address(LP_TOKEN)), amountToStake / (1e14)); // expect <= 0.01% amount left
        assertLe(rewardToken.balanceOf(address(boycoInterpolVault)), rewardsToMint / (1e14)); // expect <= 0.01% amount left
    }

    function test_upgrade() public {
        vm.startPrank(THJ);
        Options memory options;
        options.referenceContract = "BoycoInterpolVault.sol";
        Upgrades.upgradeProxy(
            address(boycoInterpolVault),
            "BoycoInterpolVaultV2.sol",
            "",
            options
        );
        vm.stopPrank();

        BoycoInterpolVaultV2 boycoInterpolVault_ = BoycoInterpolVaultV2(payable(address(boycoInterpolVault)));
        assertEq(boycoInterpolVault_.emergency(), 100);
    }
}
