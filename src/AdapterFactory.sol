// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";

import {IVaultAdapter} from "./utils/IVaultAdapter.sol";

contract AdapterFactory {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error AdapterFactory__CallerMustBeLocker();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event AdapterCreated(
        address indexed logic,
        address indexed locker,
        address vault,
        address stakingToken,
        address adapter
    );
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    /// @notice                 Creates a new adapter instance for a vault
    /// @dev                    Uses minimal proxy pattern to clone the adapter logic contract
    /// @param  logic           The address of the adapter logic contract to clone
    /// @param  locker          The address of the Locker contract that will control this adapter
    /// @param  vault           The address of the vault contract this adapter will interact with
    /// @param  stakingToken    The address of the token that can be staked in the vault
    /// @return adapter         The address of the newly created adapter instance
    function createAdapter(
        address logic,
        address locker,
        address vault,
        address stakingToken
    ) external returns (address adapter) {
        if (msg.sender != locker) revert AdapterFactory__CallerMustBeLocker();

        adapter = LibClone.clone(0, logic);

        IVaultAdapter(adapter).initialize(locker, vault, stakingToken);

        emit AdapterCreated(logic, locker, vault, stakingToken, adapter);
    }
}
