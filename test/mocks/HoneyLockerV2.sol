// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {HoneyLocker} from "../../src/HoneyLocker.sol";

contract HoneyLockerV2 is HoneyLocker {
    event Fart();
    function fart() external {
        emit Fart();
    }
}
