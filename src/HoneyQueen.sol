// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";

contract HoneyQueen is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error HoneyQueen__AdapterNotApproved();
    error HoneyQueen__VaultNotApproved();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event AdapterApproved(address indexed vault, address adapter, bool approved);
    event AdapterFactorySet(address oldFactory, address newFactory);
    event VaultAdapterSet(address indexed vault, address adapter);
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
    // tracks the latest adapter for a vault
    mapping(address vault => AdapterParams params)  public vaultToAdapterParams;
    address                                         public adapterFactory;
    
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
        emit AdapterApproved(vault, adapter, approved);
    }

    /**
     * @notice          Sets the adapter for a vault
     * @param vault     The vault address
     * @param adapter   The adapter address
     * @param token     The token address
     */
    function setVaultAdapter(address vault, address adapter, address token) external onlyOwner {
        vaultToAdapterParams[vault] = AdapterParams(adapter, token);
        emit VaultAdapterSet(vault, adapter);
    }

    /**
     * @notice Sets the authorized adapter factory
     * @param _adapterFactory The new factory address
     */
    function setAdapterFactory(address _adapterFactory) external onlyOwner {
        adapterFactory = _adapterFactory;
        emit AdapterFactorySet(adapterFactory, _adapterFactory);
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
}
