// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IVaultAdapter} from "../utils/IVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBGTStationGauge {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
    function whitelistedTokens(uint256 index) external view returns (address);
    function getWhitelistedTokensCount() external view returns (uint256);
}

contract BGTStation is IVaultAdapter {
    IBGTStationGauge public bgtStationGauge;
    address public token;
    address public locker;
    bool private initialized;

    modifier onlyLocker() {
        require(msg.sender == locker, "Not authorized");
        _;
    }

    function initialize(
        address _locker,
        address _vault,
        address _stakingToken
    ) external {
        require(!initialized, "Already initialized");
        locker = _locker;
        bgtStationGauge = IBGTStationGauge(_vault);
        token = _stakingToken;
        initialized = true;
    }

    function stake(uint256 amount) external override onlyLocker {
        ERC20(token).approve(address(bgtStationGauge), amount);
        bgtStationGauge.stake(amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        bgtStationGauge.withdraw(amount);
        // Tokens now held by adapter, send them back to the locker
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker {
        bgtStationGauge.getReward(address(this));
        uint256 rewardCount = bgtStationGauge.getWhitelistedTokensCount();
        for (uint256 i; i < rewardCount; i++) {
            address rewardToken = bgtStationGauge.whitelistedTokens(i);
            uint256 rewardAmount = ERC20(rewardToken).balanceOf(address(this));
            ERC20(rewardToken).transfer(locker, rewardAmount);
        }
    }

    function stakingToken() external view override returns (address) {
        return token;
    }

    function vault() external view override returns (address) {
        return address(bgtStationGauge);
    }
}
