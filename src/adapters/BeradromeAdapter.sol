// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBeradromePlugin {
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
    function getGauge() external view returns (address);
}

interface IBeradromeGauge {
    function getReward(address account) external;
    function getRewardTokens() external view returns (address[] memory);
    function earned(address account, address _rewardsToken) external view returns (uint256);
}

contract BeradromeAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IBeradromePlugin public beradromePlugin;
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
        beradromePlugin = IBeradromePlugin(_vault);
        token = _stakingToken;
        emit Initialized(locker, _vault, _stakingToken);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).transferFrom(locker, address(this), amount);
        ERC20(token).approve(address(beradromePlugin), amount);
        beradromePlugin.depositFor(address(this), amount);
        emit Staked(locker, address(beradromePlugin), token, amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        beradromePlugin.withdrawTo(address(this), amount);
        ERC20(token).transfer(locker, amount);
        emit Unstaked(locker, address(beradromePlugin), token, amount);
    }

    function claim() external override onlyLocker {
        IBeradromeGauge gauge = IBeradromeGauge(beradromePlugin.getGauge());
        gauge.getReward(address(this));
        address[] memory rewardTokens = gauge.getRewardTokens();
        for (uint256 i; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(this));
            ERC20(rewardToken).transfer(locker, rewardAmount);
            emit Claimed(locker, address(beradromePlugin), rewardToken, rewardAmount);
        }
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
        return address(beradromePlugin);
    }
}
