
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

interface IInfraredVault {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external returns (uint256);
    function rewardTokens() external view returns (address[] memory);
    function earned(address account, address rewardToken) external view returns (uint256);
    function stakingToken() external view returns (address);
}

contract BGTStationAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IInfraredVault public infraredVault;
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
        infraredVault = IInfraredVault(_vault);
        // Ensure consistency by getting token from vault itself
        token = infraredVault.stakingToken();

        emit Initialized(locker, _vault, token);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC721(token).transferFrom(msg.sender, address(this), amount);
        ERC721(token).approve(address(infraredVault), amount);
        infraredVault.stake(amount);
        emit Staked(locker, address(infraredVault), token, amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        infraredVault.withdraw(amount);
        ERC20(token).transfer(locker, amount);
        emit Unstaked(locker, address(infraredVault), token, amount);
    }

    function claim() external override onlyLocker {
        address[] memory rewardTokens = infraredVault.rewardTokens();
        uint256[] memory earned = new uint256[](rewardTokens.length);
        for (uint256 i; i < rewardTokens.length; i++) {
            earned[i] = infraredVault.earned(address(this), rewardTokens[i]);
            emit Claimed(locker, address(infraredVault), rewardTokens[i], earned[i]);
        }
        infraredVault.getReward();

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
        return address(infraredVault);
    }
}

