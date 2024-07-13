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
    address public treasury;
    uint256 public fees = 200; // in bps
    IBGT public constant BGT = IBGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    // prettier-ignore
    mapping(address stakingContract => bool allowed) public isStakingContractAllowed;
    mapping(bytes4 selector => mapping(string action => mapping(address stakingContract => bool allowed)))
        public isSelectorAllowed;
    // this is for cases where gauges give you a NFT to represent your staking position
    mapping(address token => bool blocked) public isTokenBlocked;
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
    function setIsStakingContractAllowed(
        address _stakingContract,
        bool _isAllowed
    ) external onlyOwner {
        isStakingContractAllowed[_stakingContract] = _isAllowed;
    }

    function setIsSelectorAllowed(
        bytes4 _selector,
        string memory _action,
        address _stakingContract,
        bool _isAllowed
    ) external onlyOwner {
        isSelectorAllowed[_selector][_action][_stakingContract] = _isAllowed;
    }

    function setIsTokenBlocked(
        address _token,
        bool _isBlocked
    ) external onlyOwner {
        isTokenBlocked[_token] = _isBlocked;
    }

    // prettier-ignore
    function setMigrationFlag(
        bool _isMigrationEnabled,
        bytes32 _fromCodeHash,
        bytes32 _toCodeHash
    ) external onlyOwner {
        isMigrationEnabled[_fromCodeHash][_toCodeHash] = _isMigrationEnabled;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setFees(uint256 _fees) external onlyOwner {
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
