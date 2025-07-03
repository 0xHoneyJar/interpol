// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {Solarray} from "solarray/Solarray.sol";

import {BaseTest} from "../Base.t.sol";
import {HoneyLockerV3} from "../../src/HoneyLockerV3.sol";
import {BoycoInterpolVaultV3} from "../../src/collabs/boyco/BoycoInterpolVaultV3.sol";

contract BoycoWithdrawalTest is BaseTest {
    // Interpol locker
    address     payable public constant LOCKER          = payable(0xc608F09763C6B93D914159e0E664efd91899C7e1);
    // Boyco X Interpol vault
    address     payable public constant BOYCO_VAULT     = payable(0xC0ab623479371af246DD11872586720683B61e43);
    // owner of both vault and locker
    address             public constant OWNER           = 0x13410d942673826b49Ccf78f80303152485F9370;
    address             public constant HUB_VAULT       = 0xF99be47baf0c22B7eB5EAC42c8D91b9942Dc7e84;
    address             public constant WEIROLL         = 0x91C17C8a6FB67f34c56a6f76e6A86d83DC1cCF0B;
    // USDC.e-HONEY LP token
    ERC20               public constant LP_TOKEN        = ERC20(0xF961a8f6d8c69E7321e78d254ecAfBcc3A637621);
    // henlo token
    ERC20               public constant HENLO           = ERC20(0xb2F776e9c1C926C4b2e54182Fac058dA9Af0B6A5);

    uint256             public constant LOST_SHARES     = 0.001 ether;


    function setUp() public override {
        vm.createSelectFork("https://rpc.berachain.com");

        vm.label(LOCKER, "LOCKER");
        vm.label(BOYCO_VAULT, "BOYCO_VAULT");
        vm.label(OWNER, "OWNER");
        vm.label(HUB_VAULT, "HUB_VAULT");
        vm.label(WEIROLL, "WEIROLL");
        vm.label(address(HENLO), "HENLO");
        vm.label(address(LP_TOKEN), "LP_TOKEN");
        vm.label(address(0x1), "USER_1");
        vm.label(address(0x2), "USER_2");
        vm.label(address(0x3), "USER_3");
    }

    /*
    In order to allow withdrawals, we need to first be sure that ;
    - henlo is set in the vault
    - vault is set in the vault
    - the vault is both the operator and the treasury of the locker
    - send out the HENLO tokens to the vault

    Then users should be able to withdraw their LP tokens and henlo tokens with ease.

    ------------------------------------------------------------

    The total supply of the vault shares is 4200001000000000000000 and for testing purposes,
    we will just distribute it amongst a few addresses.

    */
    function test_withdrawal() public {
        assertGe(HENLO.balanceOf(address(BOYCO_VAULT)), 2216472764029384056390497758);

        // uint256 initialHENLO = HENLO.balanceOf(address(BOYCO_VAULT));
        // uint256 initialLP = HoneyLockerV3(LOCKER).totalLPStaked(address(HUB_VAULT));

        console2.log("initial HENLO", HENLO.balanceOf(address(BOYCO_VAULT)));
        console2.log("initial LP", HoneyLockerV3(LOCKER).totalLPStaked(address(LP_TOKEN)));

        address[] memory addresses = Solarray.addresses(address(0x1), address(0x2), address(0x3));
        uint256[] memory amounts = Solarray.uint256s(2200 ether, 1000 ether, 1000 ether);

        for(uint256 i; i < addresses.length; i++) {
            vm.prank(WEIROLL);
            BoycoInterpolVaultV3(BOYCO_VAULT).transfer(addresses[i], amounts[i]);
            vm.prank(addresses[i]);
            BoycoInterpolVaultV3(BOYCO_VAULT).redeem(amounts[i], addresses[i]);
        }

        assertEq(BoycoInterpolVaultV3(BOYCO_VAULT).totalSupply(), 0.001 ether);

        (uint256 lostLP, uint256 lostHENLO) = BoycoInterpolVaultV3(BOYCO_VAULT).previewRedeem(LOST_SHARES);
        assertApproxEqAbs(HENLO.balanceOf(address(BOYCO_VAULT)), lostHENLO, 1e16);
        assertApproxEqAbs(HoneyLockerV3(LOCKER).totalLPStaked(address(LP_TOKEN)), lostLP, 1e16);

        // every user should have a positive balance of LP and henlo
        for(uint256 i; i < addresses.length; i++) {
            assertGt(LP_TOKEN.balanceOf(addresses[i]), 0, "LP should be > 0");
            assertGt(HENLO.balanceOf(addresses[i]), 0, "HENLO should be > 0");
        }
    }
}
