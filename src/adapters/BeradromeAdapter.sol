// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IVaultAdapter} from "../utils/IVaultAdapter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IBeradromeVault {
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
    function getReward(address account) external;
    function getRewardTokens() external view returns (address[] memory);
    function stakingToken() external view returns (address);
}

contract BeradromeAdapter is IVaultAdapter {
    IBeradromeVault public beradromeVault;
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
        beradromeVault = IBeradromeVault(_vault);
        token = _stakingToken;
        initialized = true;
    }

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
        }
    }

    function stakingToken() external view override returns (address) {
        return token;
    }

    function vault() external view override returns (address) {
        return address(beradromeVault);
    }
}
