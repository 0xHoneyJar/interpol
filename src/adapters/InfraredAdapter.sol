
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {DynamicArrayLib as DAL} from "solady/utils/DynamicArrayLib.sol";

import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";

interface IInfraredVault {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event RewardPaid(address indexed account, address indexed rewardsToken, uint256 reward);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function rewardTokens(uint256 index) external view returns (address);
    function earned(address account, address rewardToken) external view returns (uint256);
    function stakingToken() external view returns (address);
}

contract InfraredAdapter is BaseVaultAdapter {
    using DAL for address[];
    using DAL for uint256[];
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
                            INTERNAL
    ###############################################################*/
    function _earned() internal view returns (address[] memory, uint256[] memory) {
        // we use 10 as very optimistic
        address[] memory rewardTokens = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256 realLength;
        for (uint256 i; i < rewardTokens.length; i++) {
            try infraredVault.rewardTokens(i) returns (address token) {
                rewardTokens[realLength] = token;
                amounts[realLength] = infraredVault.earned(address(this), token);
                realLength++;
            } catch {
                break;
            }
        }
        return (rewardTokens.toUint256Array().truncate(realLength).asAddressArray(), amounts.truncate(realLength));
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(uint256 amount) external override onlyLocker {
        ERC721(token).transferFrom(msg.sender, address(this), amount);
        ERC721(token).approve(address(infraredVault), amount);
        infraredVault.stake(amount);
    }

    function unstake(uint256 amount) external override onlyLocker {
        infraredVault.withdraw(amount);
        ERC20(token).transfer(locker, amount);
    }

    function claim() external override onlyLocker returns (address[] memory, uint256[] memory) {
        (address[] memory rewardTokens, uint256[] memory amounts) = _earned();
        infraredVault.getReward();
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
        return address(infraredVault);
    }

    function earned() external view override returns (address[] memory, uint256[] memory) {
        return _earned();
    }
}

