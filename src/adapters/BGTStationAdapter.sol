// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRelaxedERC20} from "../utils/RelaxedERC20.sol";
import {BaseVaultAdapter} from "./BaseVaultAdapter.sol";

interface IBGTStationGauge {
    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account, address recipient) external returns (uint256);
    function setOperator(address operator) external;
    function earned(address account) external view returns (uint256);
    function stakeToken() external view returns (address);
    function rewardToken() external view returns (address);
}

contract BGTStationAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    uint256[50] __gap_;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
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
                            INTERNAL
    ###############################################################*/
    function _earned(address vault) internal view returns (address[] memory, uint256[] memory) {
        address rewardToken = IBGTStationGauge(vault).rewardToken();
        uint256 earnedAmount = IBGTStationGauge(vault).earned(address(this));

        address[] memory rewardTokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        rewardTokens[0] = rewardToken;
        amounts[0] = earnedAmount;
        return (rewardTokens, amounts);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IBGTStationGauge bgtStationGauge = IBGTStationGauge(vault);
        address token = bgtStationGauge.stakeToken();

        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        SafeERC20.forceApprove(IERC20(token), address(bgtStationGauge), amount);
        bgtStationGauge.stake(amount);
        return amount;
    }

    function unstake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IBGTStationGauge bgtStationGauge = IBGTStationGauge(vault);
        address token = bgtStationGauge.stakeToken();

        bgtStationGauge.withdraw(amount);
        SafeERC20.safeTransfer(IERC20(token), locker, amount);
        return amount;
    }

    function claim(address vault) external override onlyLocker isVaultValid(vault) returns (address[] memory, uint256[] memory) {
        (address[] memory rewardTokens, uint256[] memory amounts) = _earned(vault);
        IBGTStationGauge(vault).getReward(address(this), locker);
        return (rewardTokens, amounts);
    }

    function wildcard(address vault, uint8 func, bytes calldata args) external override onlyLocker isVaultValid(vault) {
        revert BaseVaultAdapter__NotImplemented();
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken(address vault) external view override returns (address) {
        return IBGTStationGauge(vault).stakeToken();
    }

    function earned(address vault) external view override returns (address[] memory, uint256[] memory) {
        return _earned(vault);
    }


    function version() external pure override returns (string memory) {
        return "1.0";
    }
}

