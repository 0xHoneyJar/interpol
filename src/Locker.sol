// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./adapters/BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AdapterFactory} from "./AdapterFactory.sol";

contract Locker is Ownable {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event VaultRegistered(
        address vault,
        address adapter,
        address logic
    );
    /*###############################################################
                            STORAGE
    ###############################################################*/
    AdapterFactory                          public factory;
    // vaultId => adapter instance
    mapping(address vault => BaseVaultAdapter adapter)    public vaultToAdapter;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _factory) {
        factory = AdapterFactory(_factory);
    }
    /*###############################################################
                            OWNER
    ###############################################################*/
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

    /*###############################################################
                            EXTERNAL
    ###############################################################*/
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
