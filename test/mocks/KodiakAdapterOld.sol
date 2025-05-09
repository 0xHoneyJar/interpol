// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {DynamicArrayLib as DAL} from "solady/utils/DynamicArrayLib.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {BaseVaultAdapter} from "../../src/adapters/BaseVaultAdapter.sol";

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

contract KodiakAdapterOld is Initializable, BaseVaultAdapter {
    using DAL for address[];
    using DAL for uint256[];
    using DAL for DAL.DynamicArray;
    /*###############################################################
                            STORAGE
    ###############################################################*/
    uint256[50] __gap_;
    /*###############################################################
                            INITIALIZATION
    ###############################################################*/
    function initialize(
        address _locker,
        address _honeyQueen,
        address _adapterBeacon
    ) external override initializer {
        locker = _locker;
        honeyQueen = _honeyQueen;
        adapterBeacon = _adapterBeacon;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address token = kodiakFarm.stakingToken();

        ERC20(token).transferFrom(locker, address(this), amount);
        ERC20(token).approve(address(kodiakFarm), amount);
        kodiakFarm.stakeLocked(amount, kodiakFarm.lock_time_for_max_multiplier());
        return amount;
    }

    function unstake(address vault, uint256 kekIdAsUint) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address token = kodiakFarm.stakingToken();

        kodiakFarm.withdrawLocked(bytes32(kekIdAsUint));
        uint256 amount = ERC20(token).balanceOf(address(this));
        ERC20(token).transfer(locker, amount);
        return amount;
    }

    function claim(address vault) external override onlyLocker isVaultValid(vault) returns (address[] memory, uint256[] memory) {
        IKodiakFarm kodiakFarm = IKodiakFarm(vault);
        address[] memory rewardTokens = kodiakFarm.getAllRewardTokens();
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        kodiakFarm.getReward();
        for (uint256 i; i < rewardTokens.length; i++) {
            amounts[i] = ERC20(rewardTokens[i]).balanceOf(address(this));
            /*
                we skip the transfer, to not block any other rewards
                it can always be retrieved later because we use the balanceOf() function
            */
            try ERC20(rewardTokens[i]).transfer(locker, amounts[i]) {} catch {
                emit Adapter__FailedTransfer(locker, rewardTokens[i], amounts[i]);
                amounts[i] = 0;
            }
        }
        return (rewardTokens, amounts);
    }

    // Do not implement xkdk redeem/finalizeRedeem
    function wildcard(address vault, uint8 func, bytes calldata args) external override onlyLocker isVaultValid(vault) {
        revert BaseVaultAdapter__NotImplemented();
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken(address vault) external view override returns (address) {
        return IKodiakFarm(vault).stakingToken();
    }
    function earned(address vault) public view override returns (address[] memory, uint256[] memory) {
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

