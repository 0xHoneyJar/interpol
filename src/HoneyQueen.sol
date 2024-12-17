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
    error HoneyQueen__AdapterAlreadyExists();
    error HoneyQueen__InvalidProtocol();
    error HoneyQueen__AdapterNotSet();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event HoneyQueen__AdapterApproved(address indexed vault, address adapter, bool approved);
    event HoneyQueen__VaultAdapterSet(address indexed vault, address adapter);
    event HoneyQueen__AdapterUpgraded(string indexed protocol, address indexed fromLogic, address toLogic);
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(string protocol => address adapter)         public    adapterOfProtocol;
    // have to build a reverse mapping to allow lockers to query
    mapping(address adapter => string protocol)         public    protocolOfAdapter;
    mapping(address vault => string protocol)           public    protocolOfVault;
    mapping(address vault => address token)             public    tokenOfVault;
    
    // this is for cases where gauges give you a NFT to represent your staking position
    mapping(address token => bool blocked)              public      isTokenBlocked;
    mapping(address token => bool isRewardToken)        public      isRewardToken;
    address                                             public      adapterFactory;
    address                                             public      beekeeper;
    uint256                                             public      protocolFees;
    // authorized upgrades for proxies from logic to logic
    mapping(address fromLogic => address toLogic)       public      upgradeOf;
    
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _adapterFactory) {
        adapterFactory = _adapterFactory;
        _initializeOwner(msg.sender);
    }

    /*###############################################################
                            ADAPTERS MANAGEMENT
    ###############################################################*/
    /**
     * @notice          Adds a new adapter implementation for a protocol
     * @param protocol  The protocol name
     * @param adapter   The adapter implementation address
     * @dev             It should NOT be possible to set a new adapter, therefore an upgrade,
                        for a protocol that already has one because that should be done in the
                        appropriate function setUpgradeOf
     */
    function setAdapterForProtocol(string calldata protocol, address adapter) external onlyOwner {
        if (adapterOfProtocol[protocol] != address(0)) revert HoneyQueen__AdapterAlreadyExists();
        adapterOfProtocol[protocol] = adapter;
        protocolOfAdapter[adapter] = protocol;
    }
    /**
     * @notice          Approves or revokes a vault for a protocol
     * @param protocol  The protocol name
     * @param vault     The vault address
     * @param approved  Whether the vault should be approved
     */
    function setVaultForProtocol(
        string calldata protocol,
        address vault,
        address token,
        bool approved
    ) external onlyOwner {
        if (adapterOfProtocol[protocol] == address(0)) revert HoneyQueen__AdapterNotSet();
        if (approved) {
            protocolOfVault[vault] = protocol;
            tokenOfVault[vault] = token;
        } else {
            delete protocolOfVault[vault];
        }
    }

    function setUpgradeOf(address fromLogic, address toLogic) external onlyOwner {
        upgradeOf[fromLogic] = toLogic;

        // update the mappings
        string memory protocol = protocolOfAdapter[fromLogic];
        protocolOfAdapter[toLogic] = protocol;
        adapterOfProtocol[protocol] = toLogic;

        emit HoneyQueen__AdapterUpgraded(protocol, fromLogic, toLogic);
    }

    /*###############################################################
                            OWNER MANAGEMENT
    ###############################################################*/
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
    /*###############################################################
                            READ FUNCTIONS
    ###############################################################*/
    function computeFees(uint256 amount) public view returns (uint256) {
        return FPML.mulDivUp(amount, protocolFees, 10000);
    }

    function getAdapterParams(address vault) public view returns (address, address) {
        string memory protocol = protocolOfVault[vault];
        address logic = adapterOfProtocol[protocol];
        address token = tokenOfVault[vault];
        return (logic, token);
    }

    function isVaultValidForAdapter(address adapter, address vault) public view returns (bool) {
        return adapterOfProtocol[protocolOfVault[vault]] == adapter;
    }
}
