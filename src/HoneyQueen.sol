// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";

contract HoneyQueen is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error HoneyQueen__AdapterNotApproved();
    error HoneyQueen__VaultNotApproved();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event HoneyQueen__AdapterApproved(address indexed vault, address adapter, bool approved);
    event HoneyQueen__VaultAdapterSet(address indexed vault, address adapter);
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    struct AdapterParams {
        address logic;
        address token;
    }
    /*###############################################################
                            STORAGE
    ###############################################################*/
    // adapter = logic of adapter
    mapping(address vault => mapping(address adapter => bool approved)) public isAdapterForVaultApproved;
    // this is for cases where gauges give you a NFT to represent your staking position
    mapping(address token => bool blocked)              public isTokenBlocked;
    mapping(address token => bool isRewardToken)        public isRewardToken;
    // tracks the latest adapter for a vault
    mapping(address vault => AdapterParams params)      public vaultToAdapterParams;
    address                                             public adapterFactory;
    address                                             public beekeeper;
    uint256                                             public protocolFees;
    // authorized upgrades for proxies from logic to logic
    mapping(address fromLogic => address toLogic)       public upgradeOf;
    /* 
        tracks all vaults associated to an adapter, for a given protocol, therefore array of vaults
        there should only be ONE adapter at anytime
    */
    mapping(address adapter => address[] vaults)        public adapterVaults;
    
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _adapterFactory) {
        adapterFactory = _adapterFactory;
        _initializeOwner(msg.sender);
    }

    /*###############################################################
                            OWNER FUNCTIONS
    ###############################################################*/
    /**
     * @notice          Approves or revokes an adapter implementation for a vault
     * @param vault     The vault address
     * @param adapter   The adapter implementation address
     * @param approved  Whether the adapter should be approved
     */
    function setAdapterApproval(
        address vault,
        address adapter,
        bool approved
    ) external onlyOwner {
        isAdapterForVaultApproved[vault][adapter] = approved;
        emit HoneyQueen__AdapterApproved(vault, adapter, approved);
    }

    /**
     * @notice          Sets the adapter for a vault that will be used 
                        to be cloned by the AdapterFactory
     * @param vault     The vault address
     * @param adapter   The adapter address
     * @param token     The token address
     */
    function setVaultAdapter(address vault, address adapter, address token) external onlyOwner {
        vaultToAdapterParams[vault] = AdapterParams(adapter, token);
        emit HoneyQueen__VaultAdapterSet(vault, adapter);
    }

    function setUpgradeOf(address fromLogic, address toLogic) external onlyOwner {
        upgradeOf[fromLogic] = toLogic;
    }

    function setTokenBlocked(address token, bool blocked) external onlyOwner {
        isTokenBlocked[token] = blocked;
    }

    function setIsRewardToken(address token, bool _isRewardToken) external onlyOwner {
        isRewardToken[token] = _isRewardToken;
    }

    function setAdapterFactory(address _adapterFactory) external onlyOwner {
        adapterFactory = _adapterFactory;
    }

    function setBeekeeper(address _beekeeper) external onlyOwner {
        beekeeper = _beekeeper;
    }

    function setProtocolFees(uint256 _protocolFees) external onlyOwner {
        protocolFees = _protocolFees;
    }

    /*###############################################################
                            EXTERNAL FUNCTIONS
    ###############################################################*/
    /**
     * @notice Validates an adapter deployment
     * @dev Called by AdapterFactory before creating a new adapter
     * @param logic The adapter implementation to validate
     * @param vault The vault address the adapter will interact with
     * @return _ Whether the adapter deployment is valid
     */
    function validateAdapterDeployment(
        address logic,
        address vault
    ) external view returns (bool) {
        if (msg.sender != adapterFactory) return false;
        
        return isAdapterForVaultApproved[vault][logic];
    }
    /*###############################################################
                            READ FUNCTIONS
    ###############################################################*/
    function computeFees(uint256 amount) public view returns (uint256) {
        return FPML.mulDivUp(amount, protocolFees, 10000);
    }
}
