// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {HoneyVault} from "./HoneyVault.sol";

contract Factory {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event NewVault(address indexed owner, address vault);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address internal immutable HONEY_QUEEN;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _honeyQueen) {
        HONEY_QUEEN = _honeyQueen;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function clone(
        address _owner,
        address _referral,
        bool _unlocked
    ) external returns (HoneyVault) {
        HoneyVault vault = new HoneyVault();
        vault.initialize(_owner, HONEY_QUEEN, _referral, _unlocked);
        emit NewVault(_owner, address(vault));
        return vault;
    }
}