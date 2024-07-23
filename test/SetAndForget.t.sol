// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";
import {HoneyVault} from "../src/HoneyVault.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {HoneyVaultV2} from "./mocks/HoneyVaultV2.sol";
import {FakeVault} from "./mocks/FakeVault.sol";
import {FakeGauge} from "./mocks/FakeGauge.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
}

contract HoneyVaultTest is Test {
    using LibString for uint256;

    HoneyVault public vaultToBeCloned;
    HoneyVault public honeyVault;
    HoneyQueen public honeyQueen;

    uint256 public expiration;
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);

    // IMPORTANT
    // BARTIO ADDRESSES
    // prettier-ignore
    ERC20 public constant HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    // prettier-ignore
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    // prettier-ignore
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/");
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury);
        // prettier-ignore
        honeyQueen.setIsTargetContractAllowed(address(HONEYBERA_STAKING), true);
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("stake(uint256)")),
            "stake",
            address(HONEYBERA_STAKING),
            true
        );
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("withdraw(uint256)")),
            "unstake",
            address(HONEYBERA_STAKING),
            true
        );
        honeyQueen.setIsSelectorAllowed(
            bytes4(keccak256("getReward(address)")),
            "rewards",
            address(HONEYBERA_STAKING),
            true
        );
        vaultToBeCloned = new HoneyVault();
        honeyVault = HoneyVault(payable(vaultToBeCloned.clone()));
        honeyVault.initialize(THJ, address(honeyQueen), referral, true);
        vm.stopPrank();

        vm.label(address(honeyVault), "HoneyVault");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(msg.sender, "THJ");
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_singleDepositWithNoLock() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyVault), balance);

        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.Deposited(address(HONEYBERA_LP), balance);
        vm.expectEmit(true, false, false, true, address(honeyVault));
        emit HoneyVault.LockedUntil(address(HONEYBERA_LP), expiration);
        honeyVault.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        assertEq(HONEYBERA_LP.balanceOf(address(honeyVault)), balance);

        // withdraw lp tokens now
        honeyVault.withdrawLPToken(address(HONEYBERA_LP), balance);
        assertEq(HONEYBERA_LP.balanceOf(THJ), balance);
        assertEq(HONEYBERA_LP.balanceOf(address(honeyVault)), 0);
    }
}
