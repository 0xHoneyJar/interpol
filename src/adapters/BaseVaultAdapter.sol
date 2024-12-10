// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

abstract contract BaseVaultAdapter {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error BaseVaultAdapter__AlreadyInitialized();
    error BaseVaultAdapter__NotAuthorized();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Initialized(address locker, address vault, address stakingToken);
    event Staked(address indexed locker, address indexed vault, uint256 amount);
    event Unstaked(address indexed locker, address indexed vault, uint256 amount);
    event Claimed(address indexed locker, address indexed vault, uint256 amount);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address public token;
    address public locker;
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    modifier onlyLocker() {
        if (msg.sender != locker) revert BaseVaultAdapter__NotAuthorized();
        _;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function initialize(address locker, address vault, address stakingToken) external virtual;
    function stake(uint256 amount) external virtual;
    function unstake(uint256 amount) external virtual;
    function claim() external virtual;
    function stakingToken() external view virtual returns (address);
    function vault() external view virtual returns (address);
}

