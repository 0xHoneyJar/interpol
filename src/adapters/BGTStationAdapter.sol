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
    function getReward(address account) external returns (uint256);
    function setOperator(address operator) external;
    function earned(address account) external view returns (uint256);
    function STAKE_TOKEN() external view returns (address);
    function REWARD_TOKEN() external view returns (address);
}

contract BGTStationAdapter is BaseVaultAdapter {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(address vault => bool isOperator) internal _hasSetOperator;
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
        address _honeyQueen
    ) external override initializer {
        locker = _locker;
        honeyQueen = _honeyQueen;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function stake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IBGTStationGauge bgtStationGauge = IBGTStationGauge(vault);
        address token = bgtStationGauge.STAKE_TOKEN();

        // quick check if the operator is set
        if (!_hasSetOperator[vault]) {
            bgtStationGauge.setOperator(locker);
            _hasSetOperator[vault] = true;
        }

        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        SafeERC20.forceApprove(IERC20(token), address(bgtStationGauge), amount);
        bgtStationGauge.stake(amount);
        return amount;
    }

    function unstake(address vault, uint256 amount) external override onlyLocker isVaultValid(vault) returns (uint256) {
        IBGTStationGauge bgtStationGauge = IBGTStationGauge(vault);
        address token = bgtStationGauge.STAKE_TOKEN();

        bgtStationGauge.withdraw(amount);
        SafeERC20.safeTransfer(IERC20(token), locker, amount);
        return amount;
    }

    /*
        Claiming is disabled because we are exclusively relying on the locker to claim rewards.
        This is possible because we have set the locker as the operator of the gauge for this adapter.
    */
    function claim(address vault) external override onlyLocker isVaultValid(vault) returns (address[] memory, uint256[] memory) {
        revert BaseVaultAdapter__NotImplemented();
    }

    function wildcard(address vault, uint8 func, bytes calldata args) external override onlyLocker isVaultValid(vault) {
        revert BaseVaultAdapter__NotImplemented();
    }
    /*###############################################################
                            VIEW
    ###############################################################*/
    function stakingToken(address vault) external view override returns (address) {
        return IBGTStationGauge(vault).STAKE_TOKEN();
    }

    function earned(address vault) external view override returns (address[] memory, uint256[] memory) {
        address rewardToken = IBGTStationGauge(vault).REWARD_TOKEN();
        uint256 earnedAmount = IBGTStationGauge(vault).earned(address(this));

        address[] memory rewardTokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        rewardTokens[0] = rewardToken;
        amounts[0] = earnedAmount;
        return (rewardTokens, amounts);
    }


    function version() external pure override returns (string memory) {
        return "1.0";
    }
}

