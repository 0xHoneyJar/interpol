// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {HoneyQueen} from "../HoneyQueen.sol";

abstract contract BaseVaultAdapter {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error BaseVaultAdapter__AlreadyInitialized();
    error BaseVaultAdapter__NotAuthorized();
    error BaseVaultAdapter__NotImplemented();
    error BaseVaultAdapter__NotAuthorizedUpgrade();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Adapter__Initialized(address locker, address vault, address stakingToken);
    event Adapter__FailedTransfer(address indexed locker, address indexed token, uint256 amount);
    event Adapter__Upgraded(address indexed from, address indexed to);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address public              token;   // LP token
    address public              locker;
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
                            PROXY LOGIC
    ###############################################################*/
    function upgrade(address newImplementation) external onlyLocker {
        address oldImplementation = ERC1967Utils.getImplementation();
        ERC1967Utils.upgradeToAndCall(newImplementation, "");
        emit Adapter__Upgraded(oldImplementation, newImplementation);
    }
    /*###############################################################
                            VIEW/PURE
    ###############################################################*/
    function stakingToken() external view virtual returns (address);
    function vault() external view virtual returns (address);
    function earned() external view virtual returns (address[] memory rewardTokens, uint256[] memory amounts);
    function version() external pure virtual returns (uint256) {
        return 1;
    }
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}

