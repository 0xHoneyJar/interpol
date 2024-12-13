// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBeradromePlugin {
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
    function getGauge() external view returns (address);
    function getToken() external view returns (address);
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
        token = beradromePlugin.getToken();
        emit Initialized(locker, _vault, token);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).transferFrom(locker, address(this), amount);
        ERC20(token).approve(address(beradromePlugin), amount);
        beradromePlugin.depositFor(address(this), amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        beradromePlugin.withdrawTo(address(this), amount);
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker returns (address[] memory, uint256[] memory) {
        IBeradromeGauge gauge = IBeradromeGauge(beradromePlugin.getGauge());
        address[] memory rewardTokens = gauge.getRewardTokens();
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        gauge.getReward(address(this));
        for (uint256 i; i < rewardTokens.length; i++) {
            amounts[i] = ERC20(rewardTokens[i]).balanceOf(address(this));
            /*
                we skip the transfer, to not block any other rewards
                it can always be retrieved later because we use the balanceOf() function
            */
            try ERC20(rewardTokens[i]).transfer(locker, amounts[i]) {} catch {
                emit FailedTransfer(locker, rewardTokens[i], amounts[i]);
                amounts[i] = 0;
            }
        }
        return (rewardTokens, amounts);
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

    function earned() external view override returns (address[] memory, uint256[] memory) {
        IBeradromeGauge gauge = IBeradromeGauge(beradromePlugin.getGauge());
        address[] memory rewardTokens = gauge.getRewardTokens();
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        for (uint256 i; i < rewardTokens.length; i++) {
            amounts[i] = gauge.earned(address(this), rewardTokens[i]);
        }
        return (rewardTokens, amounts);
    }
}
