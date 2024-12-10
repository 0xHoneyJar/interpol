// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";

import {IVaultAdapter} from "./utils/IVaultAdapter.sol";

contract AdapterFactory {
    event AdapterCreated(address adapter);

    function createAdapter(
        address logic,
        address locker,
        address vault,
        address stakingToken
    ) external returns (address adapter) {
        adapter = LibClone.clone(0, logic);

        IVaultAdapter(adapter).initialize(locker, vault, stakingToken);
        emit AdapterCreated(adapter);
    }
}
