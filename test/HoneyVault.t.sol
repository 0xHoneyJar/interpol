// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {HoneyVault, IStakingContract} from "../src/HoneyVault.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";

contract HoneyVaultTest is Test {
    HoneyVault public vaultToBeCloned;
    HoneyVault public honeyVault;
    HoneyQueen public honeyQueen;

    // IMPORTANT
    // BARTIO ADDRESSES
    // prettier-ignore
    ERC20 public HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    // prettier-ignore
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/");
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen();
        // prettier-ignore
        honeyQueen.setLPTokenToStakingContract(address(HONEYBERA_LP), address(HONEYBERA_STAKING));
        vaultToBeCloned = new HoneyVault();
        honeyVault = HoneyVault(vaultToBeCloned.clone());
        honeyVault.initialize(msg.sender, address(honeyQueen));
    }

    modifier broadcastAsTHJ() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    function test_initializeOriginalHasNoImpact() external {
        vaultToBeCloned.initialize(address(this), address(honeyQueen));
        assertEq(address(vaultToBeCloned.owner()), address(this));
        // now we clone the vault
        honeyVault = HoneyVault(vaultToBeCloned.clone());
        assertEq(address(honeyVault.owner()), address(0));
        // initialize clone
        honeyVault.initialize(address(this), address(honeyQueen));
        assertEq(address(honeyVault.owner()), address(this));
    }

    function test_depositAndLock() external broadcastAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(msg.sender);

        vm.expectEmit(true, true, false, false, address(honeyVault));
        emit HoneyVault.DepositedAndLocked(address(HONEYBERA_LP), balance);

        honeyVault.depositAndLock(address(HONEYBERA_LP), balance);
    }
}
