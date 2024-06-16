// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";

interface IBGT {
    function redeem(address receiver, uint256 amount) external;
}

/*
    HoneyQueen is the ground source of truth as to which contracts
    are legit. It is used by HoneyVaults to know which contracts
    they can safely stake in.
*/
contract HoneyQueen is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    /*###############################################################
                            EVENTS
    ###############################################################*/
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    // struct StakeData {}
    /*###############################################################
                            STORAGE
    ###############################################################*/
    // prettier-ignore
    mapping(address LPToken => address stakeContract) public LPTokenToStakeContract;
    IBGT public constant BGT = IBGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    bool public enableMigration;
    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    constructor() {
        _initializeOwner(msg.sender);
    }
    /*###############################################################
                            OWNER LOGIC
    ###############################################################*/
    function setEnableMigration(bool _enableMigration) external onlyOwner {
        enableMigration = _enableMigration;
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/
}
