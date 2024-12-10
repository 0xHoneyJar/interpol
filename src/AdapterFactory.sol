// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";

import {BaseVaultAdapter} from "./adapters/BaseVaultAdapter.sol";
import {HoneyQueen} from "./HoneyQueen.sol";

contract AdapterFactory {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error AdapterFactory__CallerMustBeLocker();
    error AdapterFactory__InvalidAdapter();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event AdapterCreated(
        address indexed logic,
        address indexed locker,
        address indexed vault,
        address stakingToken,
        address adapter
    );
    /*###############################################################
                            STORAGE
    ###############################################################*/
    HoneyQueen public immutable honeyQueen;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _honeyQueen) {
        honeyQueen = HoneyQueen(_honeyQueen);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function createAdapter(
        address locker,
        address vault
    ) external returns (address adapter) {
        if (msg.sender != locker) revert AdapterFactory__CallerMustBeLocker();

        (address logic, address token) = honeyQueen.vaultToAdapterParams(vault);
        
        // Validate the adapter deployment through HoneyQueen
        if (logic == address(0) || token == address(0)) {
            revert AdapterFactory__InvalidAdapter();
        }

        adapter = LibClone.clone(logic);
        BaseVaultAdapter(adapter).initialize(locker, vault, token);

        emit AdapterCreated(logic, locker, vault, token, adapter);
    }
}

