// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IKodiakFarm {
    function stakeLocked(uint256 liquidity, uint256 secs) external;
    function withdrawLocked(bytes32 kek_id) external;
    function getReward() external returns (uint256[] memory);
    function getAllRewardTokens() external view returns (address[] memory);
    function lock_time_for_max_multiplier() external view returns (uint256);
}

contract KodiakAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IKodiakFarm public kodiakFarm;
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
        kodiakFarm = IKodiakFarm(_vault);
        token = _stakingToken;
        emit Initialized(locker, _vault, _stakingToken);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).approve(address(kodiakFarm), amount);
        kodiakFarm.stakeLocked(amount, kodiakFarm.lock_time_for_max_multiplier());
    }

    function unstake(uint256 amount) external override onlyLocker {
        kodiakFarm.withdrawLocked(bytes32(amount));
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker {
        uint256[] memory rewards = kodiakFarm.getReward();
        address[] memory rewardTokens = kodiakFarm.getAllRewardTokens();
        for (uint256 i; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 rewardAmount = rewards[i];
            ERC20(rewardToken).transfer(locker, rewardAmount);
            emit Claimed(locker, address(kodiakFarm), rewardToken, rewardAmount);
        }
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken() external view override returns (address) {
        return token;
    }

    function vault() external view override returns (address) {
        return address(kodiakFarm);
    }
}

