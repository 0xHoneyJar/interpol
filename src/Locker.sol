// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IVaultAdapter} from "./utils/IVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AdapterFactory} from "./AdapterFactory.sol";

contract Locker is Ownable {
    AdapterFactory public factory;

    // vaultId => adapter instance
    mapping(uint256 => IVaultAdapter) public vaultAdapters;

    event VaultRegistered(
        uint256 vaultId,
        address logic,
        address vault,
        address adapter
    );

    constructor(address _factory) {
        factory = AdapterFactory(_factory);
    }

    /**
     * @dev Register a new vault. This creates a unique adapter for the vault and stores it by vaultId.
     * @param vaultId A unique ID for this vault.
     * @param logic The address of the vault adapter logic contract (e.g., KodiakAdapter logic).
     * @param vault The address of the actual vault contract.
     */
    function registerVault(
        uint256 vaultId,
        address logic,
        address vault,
        address stakingToken
    ) external onlyOwner {
        require(
            address(vaultAdapters[vaultId]) == address(0),
            "Vault already registered"
        );
        address adapterAddr = factory.createAdapter(
            logic,
            address(this),
            vault,
            stakingToken
        );
        vaultAdapters[vaultId] = IVaultAdapter(adapterAddr);
        emit VaultRegistered(vaultId, logic, vault, adapterAddr);
    }

    /**
     * @dev Stake tokens into a chosen vault by vaultId.
     *      User must have approved this Locker to transfer their tokens.
     */
    function stake(uint256 vaultId, uint256 amount) external {
        IVaultAdapter adapter = vaultAdapters[vaultId];
        require(address(adapter) != address(0), "Vault not found");

        address token = adapter.stakingToken();
        require(
            ERC20(token).transferFrom(msg.sender, address(adapter), amount),
            "Transfer failed"
        );

        adapter.stake(amount);
    }

    /**
     * @dev Unstake tokens from a chosen vault by vaultId.
     *      Tokens are first transferred back to the Locker by the adapter, then from Locker to user.
     */
    function unstake(uint256 vaultId, uint256 amount) external {
        IVaultAdapter adapter = vaultAdapters[vaultId];
        require(address(adapter) != address(0), "Vault not found");

        adapter.unstake(amount);

        address token = adapter.stakingToken();
        require(
            ERC20(token).transfer(msg.sender, amount),
            "Transfer to user failed"
        );
    }

    /**
     * @dev Claim rewards from a chosen vault by vaultId.
     *      The handling of rewards depends on the adapter and vault.
     */
    function claim(uint256 vaultId) external {
        IVaultAdapter adapter = vaultAdapters[vaultId];
        require(address(adapter) != address(0), "Vault not found");

        adapter.claim();

        // If rewards are sent back to Locker in this call, forward them to msg.sender as needed.
        // If the vault just sends rewards directly to the Locker or user, handle accordingly.
    }
}
