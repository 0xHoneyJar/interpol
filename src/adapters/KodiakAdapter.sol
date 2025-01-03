// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {DynamicArrayLib as DAL} from "solady/utils/DynamicArrayLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRelaxedERC20} from "../utils/RelaxedERC20.sol";
import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";

interface IKodiakFarm {
    function stakeLocked(uint256 liquidity, uint256 secs) external;
    function withdrawLocked(bytes32 kek_id) external;
    function getReward() external returns (uint256[] memory);
    function getAllRewardTokens() external view returns (address[] memory);
    function lock_time_for_max_multiplier() external view returns (uint256);
    function xKdk() external view returns (address);
    function kdk() external view returns (address);
    function stakingToken() external view returns (address);
    function earned(address account) external view returns (uint256[] memory);
    function xKdkPercentage() external view returns (uint256);
    function lockedLiquidityOf(address account) external view returns (uint256);
    function sync() external;
    
    event StakeLocked(
        address indexed user,
        uint256 amount,
        uint256 secs,
        bytes32 kek_id,
        address source_address
    );
    event WithdrawLocked(
        address indexed user,
        uint256 amount,
        bytes32 kek_id,
        address destination_address
    );
    event RewardPaid(
        address indexed user,
        uint256 reward,
        address token_address,
        address destination_address
    );
}

interface XKDK {
    function redeem(uint256,uint256) external;
    function finalizeRedeem(uint256) external;
    function balanceOf(address account) external view returns (uint256);
}

contract KodiakAdapter is BaseVaultAdapter {
    using DAL for address[];
    using DAL for uint256[];
    using DAL for DAL.DynamicArray;
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(bytes32 kekId => uint256 amount) amounts;
    /*###############################################################
                            INITIALIZATION
    ###############################################################*/
    function initialize(
        address _locker,
        address _honeyQueen
    ) external override {
        if (locker != address(0)) revert BaseVaultAdapter__AlreadyInitialized();
        locker = _locker;
        honeyQueen = _honeyQueen;
    }
    /*###############################################################
                            INTERNAL
    ###############################################################*/
    function _transferRewards(address vault) internal returns (address[] memory, uint256[] memory) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address[] memory rewardTokens = kodiakFarm.getAllRewardTokens();
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        for (uint256 i; i < rewardTokens.length; i++) {
            amounts[i] = IERC20(rewardTokens[i]).balanceOf(address(this));
            /*
                we skip the transfer, to not block any other rewards
                it can always be retrieved later because we use the balanceOf() function
            */
            try IRelaxedERC20(rewardTokens[i]).transfer(locker, amounts[i]) {} catch {
                emit Adapter__FailedTransfer(locker, rewardTokens[i], amounts[i]);
                amounts[i] = 0;
            }
        }
        return (rewardTokens, amounts);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address token = kodiakFarm.stakingToken();

        SafeERC20.safeTransferFrom(IERC20(token), locker, address(this), amount);
        SafeERC20.forceApprove(IERC20(token), address(kodiakFarm), amount);
        bytes32 expectedKekId = keccak256(
            abi.encodePacked(
                address(this),
                block.timestamp,
                amount,
                kodiakFarm.lockedLiquidityOf(address(this))
            )
        );
        kodiakFarm.stakeLocked(amount, kodiakFarm.lock_time_for_max_multiplier());
        amounts[expectedKekId] = amount;
        return amount;
    }

    function unstake(address vault, uint256 kekIdAsUint) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address token = kodiakFarm.stakingToken();

        kodiakFarm.withdrawLocked(bytes32(kekIdAsUint));
        _transferRewards(vault);
        uint256 unstakedAmount = amounts[bytes32(kekIdAsUint)];
        uint256 balance = IERC20(token).balanceOf(address(this));
        delete amounts[bytes32(kekIdAsUint)];
        SafeERC20.safeTransfer(IERC20(token), locker, balance);
        return unstakedAmount;
    }

    function claim(address vault) external override onlyLocker isVaultValid(vault) returns (address[] memory, uint256[] memory) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);

        try kodiakFarm.getReward() {} catch {} // can still distribute rewards even if the call fails

        return _transferRewards(vault);
    }

    function wildcard(address vault, uint8 func, bytes calldata args) external override onlyLocker isVaultValid(vault) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        XKDK xKdk = XKDK(kodiakFarm.xKdk());
        if (func == 0) {
            (uint256 amount, uint256 duration) = abi.decode(args, (uint256, uint256));
            xKdk.redeem(amount, duration);
        } else if (func == 1) {
            (uint256 index) = abi.decode(args, (uint256));
            xKdk.finalizeRedeem(index);
            IRelaxedERC20(kodiakFarm.kdk()).transfer(locker, ERC20(kodiakFarm.kdk()).balanceOf(address(this)));
        }
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken(address vault) external view override returns (address) {
        return IKodiakFarm(vault).stakingToken();
    }

    function earned(address vault) external view override returns (address[] memory, uint256[] memory) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        DAL.DynamicArray memory rewardTokens = kodiakFarm.getAllRewardTokens().wrap();
        DAL.DynamicArray memory amounts = kodiakFarm.earned(address(this)).wrap();
        address kdk = kodiakFarm.kdk();
        uint256 xKDKAmount;
        /*
            To have an accurate result, we must reproduce the logic of the rewards payout
            meaning that a chunk of kdk goes as xKDK
        */
        for (uint256 i; i < rewardTokens.length(); i++) {
            if (rewardTokens.getAddress(i) == kdk) {
                uint256 amount = amounts.getUint256(i);
                xKDKAmount = amount * kodiakFarm.xKdkPercentage() / 100e18;
                amounts.set(i, amount - xKDKAmount);
            }
        }
        rewardTokens.p(kodiakFarm.xKdk());
        amounts.p(xKDKAmount);
        // resize arrays to include xKDK as a reward
        return (rewardTokens.asAddressArray(), amounts.asUint256Array());
    }

    function version() external pure override returns (string memory) {
        return "1.0";
    }
}

