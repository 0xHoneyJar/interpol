// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBeradromeVault {
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
    function getReward(address account) external;
    function getRewardTokens() external view returns (address[] memory);
}

contract BeradromeAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IBeradromeVault public beradromeVault;
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
        beradromeVault = IBeradromeVault(_vault);
        token = _stakingToken;
        emit Initialized(locker, _vault, _stakingToken);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).approve(address(beradromeVault), amount);
        beradromeVault.depositFor(address(this), amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        beradromeVault.withdrawTo(address(this), amount);
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker {
        beradromeVault.getReward(address(this));
        address[] memory rewardTokens = beradromeVault.getRewardTokens();
        for (uint256 i; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(this));
            ERC20(rewardToken).transfer(locker, rewardAmount);
            emit Claimed(locker, address(beradromeVault), rewardToken, rewardAmount);
        }
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken() external view override returns (address) {
        return token;
    }

    function vault() external view override returns (address) {
        return address(beradromeVault);
    }
}
