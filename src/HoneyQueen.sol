// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {Beekeeper} from "./Beekeeper.sol";
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
    event ProtocolOfTargetSet(address targetContract, string protocol);
    event SelectorAllowedForProtocol(bytes4 selector, string action, string protocol, bool allowed);
    event TokenBlocked(address token, bool blocked);
    event MigrationFlagSet(bytes32 fromCodeHash, bytes32 toCodeHash, bool isEnabled);
    event TreasurySet(address oldTreasury, address newTreasury);
    event AutomatonSet(address oldAutomaton, address newAutomaton);
    event ValidatorSet(address oldValidator, address newValidator);
    event FeesSet(uint256 oldFees, uint256 newFees);
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
    Beekeeper public immutable beekeeper;
    IBGT public immutable BGT;
    mapping(address targetContract => string protocol) public protocolOfTarget;
    mapping(bytes4 selector => mapping(string action => mapping(string protocol => bool allowed)))
        public isSelectorAllowedForProtocol;
    // this is for cases where gauges give you a NFT to represent your staking position
    mapping(address token => bool blocked) public isTokenBlocked;
    mapping(bytes32 fromCodeHash => mapping(bytes32 toCodeHash => bool isEnabled))
        public isMigrationEnabled;

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _treasury, address _BGT, address _beekeeper) {
        treasury = _treasury;
        BGT = IBGT(_BGT);
        beekeeper = Beekeeper(_beekeeper);
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
        emit ProtocolOfTargetSet(_targetContract, _protocol);
    }

    /*
        The reasoning behind this is that every protocol's staking
        contracts will follow the same ABI, so it makes sense to just
        group the selectors by protocol.
    */
    /// @notice Sets whether a selector is allowed for a specific action and protocol
    /// @dev This function allows the owner to configure which function selectors are permitted for different actions within each protocol
    /// @param _selector The function selector to be configured
    /// @param _action The action category (e.g., "stake", "unstake", "rewards")
    /// @param _protocol The protocol identifier (e.g., "BGTSTATION", "KODIAK")
    /// @param _isAllowed Boolean indicating whether the selector is allowed (true) or disallowed (false)
    /// @custom:emits SelectorAllowedForProtocol event with the selector, action, protocol, and allowed status
    function setIsSelectorAllowedForProtocol(
        bytes4 _selector,
        string memory _action,
        string memory _protocol,
        bool _isAllowed
    ) external onlyOwner {
        isSelectorAllowedForProtocol[_selector][_action][_protocol] = _isAllowed;
        emit SelectorAllowedForProtocol(_selector, _action, _protocol, _isAllowed);
    }

    function setIsTokenBlocked(
        address _token,
        bool _isBlocked
    ) external onlyOwner {
        isTokenBlocked[_token] = _isBlocked;
        emit TokenBlocked(_token, _isBlocked);
    }

    function setMigrationFlag(
        bool _isMigrationEnabled,
        bytes32 _fromCodeHash,
        bytes32 _toCodeHash
    ) external onlyOwner {
        isMigrationEnabled[_fromCodeHash][_toCodeHash] = _isMigrationEnabled;
        emit MigrationFlagSet(_fromCodeHash, _toCodeHash, _isMigrationEnabled);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasurySet(treasury, _treasury);
    }

    function setFees(uint256 _fees) external onlyOwner {
        fees = _fees;
        emit FeesSet(fees, _fees);
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
        emit ValidatorSet(validator, _validator);
    }

    function setAutomaton(address _automaton) external onlyOwner {
        automaton = _automaton;
        emit AutomatonSet(automaton, _automaton);
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    function computeFees(uint256 amount) public view returns (uint256) {
        return FPML.mulDivUp(amount, fees, 10000);
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
