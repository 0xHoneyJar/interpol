// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

abstract contract BaseVaultAdapter {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error BaseVaultAdapter__AlreadyInitialized();
    error BaseVaultAdapter__NotAuthorized();
    error BaseVaultAdapter__NotImplemented();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Initialized(address locker, address vault, address stakingToken);
    event FailedTransfer(address indexed locker, address indexed token, uint256 amount);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address public token;   // LP token
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
    function claim() external virtual returns (address[] memory rewardTokens, uint256[] memory earned);
    function wildcard(uint8 func, bytes calldata args) external virtual;
    /*###############################################################
                            VIEW/PURE
    ###############################################################*/
    function stakingToken() external view virtual returns (address);
    function vault() external view virtual returns (address);
    function earned() external view virtual returns (address[] memory rewardTokens, uint256[] memory amounts);
    function version() external pure virtual returns (uint256) {
        return 1;
    }
}

