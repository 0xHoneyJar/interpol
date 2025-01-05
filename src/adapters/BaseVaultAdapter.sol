// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {SafeTransferLib as STL} from "@openzeppelin/contracts/utils/SafeTransferLib.sol";

import {HoneyQueen} from "../HoneyQueen.sol";

abstract contract BaseVaultAdapter {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error BaseVaultAdapter__AlreadyInitialized();
    error BaseVaultAdapter__NotAuthorized();
    error BaseVaultAdapter__NotImplemented();
    error BaseVaultAdapter__NotAuthorizedUpgrade();
    error BaseVaultAdapter__InvalidVault();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Adapter__FailedTransfer(address indexed locker, address indexed token, uint256 amount);
    event Adapter__Upgraded(address indexed from, address indexed to);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address     public              locker;
    address     internal            honeyQueen;
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    modifier onlyLocker() {
        if (msg.sender != locker) revert BaseVaultAdapter__NotAuthorized();
        _;
    }
    modifier isVaultValid(address vault) {
        if (!HoneyQueen(honeyQueen).isVaultValidForAdapter(ERC1967Utils.getImplementation(), vault)) revert BaseVaultAdapter__InvalidVault();
        _;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function initialize(address locker, address _honeyQueen) external virtual;
    function stake(address vault, uint256 amount) external virtual returns (uint256);
    function unstake(address vault, uint256 amount) external virtual returns (uint256);
    function claim(address vault) external virtual returns (address[] memory rewardTokens, uint256[] memory earned);
    function wildcard(address vault, uint8 func, bytes calldata args) external virtual;
    
    function rescueERC20(address token) external virtual {
        STL.safeTransferAll(token, locker);
    }
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
    function stakingToken(address vault) external view virtual returns (address);
    function earned(address vault) external view virtual returns (address[] memory rewardTokens, uint256[] memory amounts);
    function version() external pure virtual returns (string memory);
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}

