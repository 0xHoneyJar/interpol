// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseVaultAdapter} from "./adapters/BaseVaultAdapter.sol";
import {HoneyQueen} from "./HoneyQueen.sol";

contract AdapterFactory {
    bytes32 constant EMPTY_STRING_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error AdapterFactory__CallerMustBeLocker();
    error AdapterFactory__InvalidAdapter();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event AdapterFactory__AdapterCreated(
        string indexed protocol,
        address indexed logic,
        address locker,
        address adapter
    );
    /*###############################################################
                            STORAGE
    ###############################################################*/
    HoneyQueen public immutable honeyQueen;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _honeyQueen) {
        honeyQueen = HoneyQueen(_honeyQueen);
    }
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    modifier onlyLocker(address locker) {
        if (msg.sender != locker) revert AdapterFactory__CallerMustBeLocker();
        _;
    }
    /*###############################################################
                            INTERNAL
    ###############################################################*/
    function _createAdapter(address locker, address logic) internal returns (address adapter) {
        string memory protocol = honeyQueen.protocolOfAdapter(logic);
        bytes memory data = abi.encodeWithSelector(BaseVaultAdapter.initialize.selector, locker, honeyQueen);
        adapter = address(new ERC1967Proxy(logic, data));
        emit AdapterFactory__AdapterCreated(protocol, logic, locker, adapter);
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function createAdapter(
        address locker,
        string calldata protocol
    ) external onlyLocker(locker) returns (address adapter) {
        address logic = honeyQueen.adapterOfProtocol(protocol);
        
        // Validate the adapter deployment through HoneyQueen
        if (logic == address(0)) {
            revert AdapterFactory__InvalidAdapter();
        }

        return _createAdapter(locker, logic);
    }

    function createAdapter(address locker, address logic) external onlyLocker(locker) returns (address adapter) {
        string memory protocol = honeyQueen.protocolOfAdapter(logic);
        
        // Validate the adapter deployment through HoneyQueen
        if (keccak256(abi.encodePacked(protocol)) == EMPTY_STRING_HASH) {
            revert AdapterFactory__InvalidAdapter();
        }

        return _createAdapter(locker, logic);
    }
}

