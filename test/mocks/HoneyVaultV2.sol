// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {HoneyVault} from "../../src/HoneyVault.sol";

contract HoneyVaultV2 is HoneyVault {
    event Fart();
    function fart() external {
        emit Fart();
    }
}
