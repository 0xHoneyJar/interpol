// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBGTStationGauge {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
    function whitelistedTokens(uint256 index) external view returns (address);
    function getWhitelistedTokensCount() external view returns (uint256);
}

contract BGTStation is BaseVaultAdapter {
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
        emit Initialized(locker, _vault, _stakingToken);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).approve(address(bgtStationGauge), amount);
        bgtStationGauge.stake(amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        bgtStationGauge.withdraw(amount);
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker {
        bgtStationGauge.getReward(address(this));
        uint256 rewardCount = bgtStationGauge.getWhitelistedTokensCount();
        for (uint256 i; i < rewardCount; i++) {
            address rewardToken = bgtStationGauge.whitelistedTokens(i);
            uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(this));
            ERC20(rewardToken).transfer(locker, rewardAmount);
            emit Claimed(locker, address(bgtStationGauge), rewardToken, rewardAmount);
        }
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
}
