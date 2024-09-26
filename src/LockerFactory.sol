// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {HoneyLocker} from "./HoneyLocker.sol";

contract LockerFactory {
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
    /// @notice Creates a new HoneyLocker contract
    /// @dev This function deploys a new HoneyLocker contract and initializes it with the provided parameters
    /// @param _owner The address that will own the new HoneyLocker
    /// @param _referral The address of the referrer for this locker
    /// @return HoneyLocker The newly created and initialized HoneyLocker contract
    /// @custom:emits NewLocker event with the owner's address and the new locker's address
    function clone(
        address _owner,
        address _referral
    ) external returns (address) {
        HoneyLocker locker = new HoneyLocker();
        locker.initialize(_owner, HONEY_QUEEN, _referral, false);
        emit NewLocker(_owner, address(locker));
        return address(locker);
    }
}
