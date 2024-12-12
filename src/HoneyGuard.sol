// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";

import {HoneyQueen} from "./HoneyQueen.sol";

contract HoneyGuard is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
    HoneyQueen internal honeyQueen;
    mapping(string protocol => mapping(bytes4 selector => bool toVerify)) public verifySelectors;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _honeyQueen) {
        honeyQueen = HoneyQueen(_honeyQueen);
        _initializeOwner(msg.sender);
    }
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    /*###############################################################
                            OWNER ONLY
    ###############################################################*/
    function setVerifySelector(string memory _protocol, bytes4 _selector, bool _toVerify) external onlyOwner {
        verifySelectors[_protocol][_selector] = _toVerify;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    /*
        Very brutish solution to verify that locker is somewhere in the payload.
    */
    function verify(address _target, bytes calldata _informations, bytes calldata _payload) external view returns (bool) {
        string memory protocol = honeyQueen.protocolOfTarget(_target);
        bytes4 selector = bytes4(_payload[0:4]);
        address locker = abi.decode(_informations, (address));
        bool toVerify = verifySelectors[protocol][selector];
        if (!toVerify) return true;

        string memory payloadAsString = LibString.toHexString(_payload);
        string memory targetAsString = LibString.toHexStringNoPrefix(locker);
        return LibString.contains(payloadAsString, targetAsString);
    }
}
