// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {HoneyLocker} from "./HoneyLocker.sol";

// Set&Forget Factory
contract SetAndForgetFactory {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event NewSetAndForget(address indexed owner, address setAndForget);
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
    /// @notice Creates a new SetAndForget contract
    /// @dev This function deploys a new SetAndForget contract and initializes it with the provided parameters
    /// @param _owner The address that will own the new S&F
    /// @param _referral The address of the referrer for this S&F
    /// @return HoneyLocker The newly created and initialized S&F contract
    /// @custom:emits NewSetAndForget event with the owner's address and the new setAndForget's address
    function clone(
        address _owner,
        address _referral
    ) external returns (HoneyLocker) {
        HoneyLocker locker = new HoneyLocker();
        locker.initialize(_owner, HONEY_QUEEN, _referral, true);
        emit NewSetAndForget(_owner, address(locker));
        return locker;
    }
}
