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
    address public immutable treasury;
    IBGT public constant BGT = IBGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    uint256 public fees = 200; // in bps
    // prettier-ignore
    mapping(address LPToken => address stakingContract) public LPTokenToStakingContract;
    // prettier-ignore
    mapping(bytes32 fromCodeHash => mapping(bytes32 toCodeHash => bool isEnabled)) public isMigrationEnabled;

    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    constructor(address _treasury) {
        treasury = _treasury;
        _initializeOwner(msg.sender);
    }
    /*###############################################################
                            OWNER LOGIC
    ###############################################################*/
    function setLPTokenToStakingContract(
        address _LPToken,
        address _stakingContract
    ) external onlyOwner {
        LPTokenToStakingContract[_LPToken] = _stakingContract;
    }
    // prettier-ignore
    function setMigrationFlag(
        bool _isMigrationEnabled,
        bytes32 _fromCodeHash,
        bytes32 _toCodeHash
    ) external onlyOwner {
        isMigrationEnabled[_fromCodeHash][_toCodeHash] = _isMigrationEnabled;
    }

    function updateFees(uint256 _fees) external onlyOwner {
        fees = _fees;
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    function computeFees(uint256 amount) public view returns (uint256) {
        return (amount * fees) / 10000;
    }
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/
}
