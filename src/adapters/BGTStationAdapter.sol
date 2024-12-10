// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBGTStationGauge {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
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

    function claim() external override onlyLocker {
        bgtStationGauge.getReward(address(this));
        // Since we don't know reward tokens, transfer any token balance back to locker
        uint256 rewardAmount = ERC20(token).balanceOf(address(this));
        if (rewardAmount > 0) {
            ERC20(token).transfer(locker, rewardAmount);
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

