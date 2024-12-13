// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBGTStationGauge {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external returns (uint256);
    function setOperator(address operator) external;
    function earned(address account) external view returns (uint256);
}

contract BGTStationAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IBGTStationGauge public bgtStationGauge;
    /*###############################################################
                            INITIALIZATION
    ###############################################################*/
    function initialize(
        address _locker,
        address _vault,
        address _stakingToken
    ) external override {
        if (locker != address(0)) revert BaseVaultAdapter__AlreadyInitialized();
        locker = _locker;
        bgtStationGauge = IBGTStationGauge(_vault);
        token = _stakingToken;

        // the locker will be the one receiving the rewards
        bgtStationGauge.setOperator(_locker);

        emit Initialized(locker, _vault, _stakingToken);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC721(token).transferFrom(msg.sender, address(this), amount);
        ERC721(token).approve(address(bgtStationGauge), amount);
        bgtStationGauge.stake(amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        bgtStationGauge.withdraw(amount);
        ERC20(token).transfer(locker, amount);
    }

    /*
        Claiming is disabled because we are exclusively relying on the locker to claim rewards.
        This is possible because we have set the locker as the operator of the gauge for this adapter.
    */
    function claim() external override onlyLocker returns (address[] memory, uint256[] memory) {
        revert BaseVaultAdapter__NotImplemented();
    }

    function wildcard(uint8 func, bytes calldata args) external override onlyLocker {
        revert BaseVaultAdapter__NotImplemented();
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken() external view override returns (address) {
        return token;
    }

    function vault() external view override returns (address) {
        return address(bgtStationGauge);
    }

    function earned() external view override returns (address[] memory, uint256[] memory) {
        revert BaseVaultAdapter__NotImplemented();
    }
}

