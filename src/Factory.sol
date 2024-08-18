// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {HoneyLocker} from "./HoneyLocker.sol";

contract Factory {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event NewLocker(address indexed owner, address locker);
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
    ) external returns (HoneyLocker) {
        HoneyLocker locker = new HoneyLocker();
        locker.initialize(_owner, HONEY_QUEEN, _referral, _unlocked);
        emit NewLocker(_owner, address(locker));
        return locker;
    }
}