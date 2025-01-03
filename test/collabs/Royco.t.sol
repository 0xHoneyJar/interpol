// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {BaseTest} from "../Base.t.sol";
import {HoneyLocker} from "../../src/HoneyLocker.sol";
import {BGTStationAdapter, IBGTStationGauge} from "../../src/adapters/BGTStationAdapter.sol";
import {BaseVaultAdapter as BVA} from "../../src/adapters/BaseVaultAdapter.sol";
import {BoycoInterpolVault} from "../../src/collabs/boyco/BoycoInterpolVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract RoycoTest is BaseTest {
    BGTStationAdapter   public adapter;
    BVA                 public lockerAdapter;   // adapter for BGT Station used by locker

    // LBGT-WBERA gauge
    address     public constant GAUGE       = 0x7a6b92457e7D7e7a5C1A2245488b850B7Da8E01D;
    // LBGT-WBERA LP token
    ERC20       public constant LP_TOKEN    = ERC20(0x6AcBBedEcD914dE8295428B4Ee51626a1908bB12);

    
    /*###############################################################
                            ROYCO PARAMS
    ###############################################################*/
    BoycoInterpolVault  public boycoInterpolVault;

    address             public asset;
    address             public vault            = GAUGE; 
    bytes               public validatorBytes   = hex"49e7CF782fB697CDAe1046D45778C8aE3D7eC644";
    address             public sfOperator       = makeAddr("sfOperator");

    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));

        super.setUp();

        // Deploy adapter implementation that will be cloned
        adapter = new BGTStationAdapter();
        asset = address(new MockERC20());

        vm.startPrank(THJ);

        queen.setAdapterForProtocol("BGTSTATION", address(adapter));
        queen.setVaultForProtocol("BGTSTATION", GAUGE, address(LP_TOKEN), true);

        lockerAdapter = BVA(locker.adapterOfProtocol("BGTSTATION"));

        // Deploy vault
        address _boycoInterpolVault = Upgrades.deployUUPSProxy(
            "BoycoInterpolVault.sol",
            abi.encodeCall(BoycoInterpolVault.initialize, (THJ, address(locker), asset, vault))
        );

        boycoInterpolVault = BoycoInterpolVault(payable(_boycoInterpolVault));

        // Configure vault
        boycoInterpolVault.setValidator(validatorBytes);
        HoneyLocker(payable(locker)).setOperator(sfOperator);

        // Configure locker
        HoneyLocker(payable(locker)).registerAdapter("BGTSTATION");
        HoneyLocker(payable(locker)).wildcard(vault, 0, "");
        HoneyLocker(payable(locker)).transferOwnership(address(boycoInterpolVault));
    }

    function test_initialization() public {
        assertEq(boycoInterpolVault.validator(), validatorBytes);
        assertEq(boycoInterpolVault.asset(), asset);
        assertEq(boycoInterpolVault.vault(), vault);
    }

    function test_deposit() public {
        uint256 amount = 1000;
        deal(asset, address(this), amount);

        ERC20(asset).approve(address(boycoInterpolVault), amount);
        uint256 shares = boycoInterpolVault.deposit(amount, address(this));

        assertGt(shares, 0);
        assertEq(ERC20(asset).balanceOf(address(this)), 0);
    }

    function test_redeem() public {
        uint256 amount = 1000;
        deal(asset, address(this), amount);

        ERC20(asset).approve(address(boycoInterpolVault), amount);
        uint256 shares = boycoInterpolVault.deposit(amount, address(this));

        uint256 lpReceived = boycoInterpolVault.redeem(shares, address(this));
        assertGt(lpReceived, 0);
    }
}
