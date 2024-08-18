// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {IBGT} from "./utils/IBGT.sol";

/*
    HoneyQueen is the ground source of truth as to which contracts
    are legit. It is used by HoneyLockers to know which contracts
    they can safely stake in.
*/
// prettier-ignore
contract HoneyQueen is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    /*###############################################################
                            EVENTS
    ###############################################################*/
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address public treasury;
    address public automaton; // address responsible for executing automated calls
    address public validator;
    uint256 public fees = 200; // in bps
    IBGT public immutable BGT;
    mapping(address targetContract => string protocol) public protocolOfTarget;
    mapping(bytes4 selector => mapping(string action => mapping(string protocol => bool allowed)))
        public isSelectorAllowedForProtocol;
    // this is for cases where gauges give you a NFT to represent your staking position
    mapping(address token => bool blocked) public isTokenBlocked;
    mapping(bytes32 fromCodeHash => mapping(bytes32 toCodeHash => bool isEnabled))
        public isMigrationEnabled;

    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    constructor(address _treasury, address _BGT) {
        treasury = _treasury;
        BGT = IBGT(_BGT);
        _initializeOwner(msg.sender);
    }
    /*###############################################################
                            OWNER LOGIC
    ###############################################################*/

    /*
        For more efficiency, we group contracts per "protocol"
        such as BGT Station or Kodiak.
    */
    function setProtocolOfTarget(
        address _targetContract,
        string memory _protocol
    ) external onlyOwner {
        protocolOfTarget[_targetContract] = _protocol;
    }

    /*
        The reasoning behind this is that every protocol's staking
        contracts will follow the same ABI, so it makes sense to just
        group the selectors by protocol.
    */
    function setIsSelectorAllowedForProtocol(
        bytes4 _selector,
        string memory _action,
        string memory _protocol,
        bool _isAllowed
    ) external onlyOwner {
        isSelectorAllowedForProtocol[_selector][_action][_protocol] = _isAllowed;
    }

    function setIsTokenBlocked(
        address _token,
        bool _isBlocked
    ) external onlyOwner {
        isTokenBlocked[_token] = _isBlocked;
    }

    function setMigrationFlag(
        bool _isMigrationEnabled,
        bytes32 _fromCodeHash,
        bytes32 _toCodeHash
    ) external onlyOwner {
        isMigrationEnabled[_fromCodeHash][_toCodeHash] = _isMigrationEnabled;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setFees(uint256 _fees) external onlyOwner {
        fees = _fees;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    function computeFees(uint256 amount) public view returns (uint256) {
        return (amount * fees) / 10000;
    }
    function isTargetContractAllowed(address _target) public view returns (bool allowed) {
        string memory protocol = protocolOfTarget[_target];
        assembly {
            allowed := not(iszero(protocol))
        }
    }
    function isSelectorAllowedForTarget(
        bytes4 _selector,
        string calldata _action,
        address _target
    ) public view returns (bool) {
        return isSelectorAllowedForProtocol[_selector][_action][protocolOfTarget[_target]];
    }
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/
}
