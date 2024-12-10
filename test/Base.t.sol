// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {AdapterFactory} from "../src/AdapterFactory.sol";
import {TokenReceiver} from "../src/utils/TokenReceiver.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

abstract contract BaseTest is Test, TokenReceiver {
    /*###############################################################
                            CONSTANTS
    ###############################################################*/
    address internal THJ = makeAddr("THJ");

    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    HoneyLocker public locker;
    HoneyQueen public queen;
    AdapterFactory public factory;

    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual {
        vm.startPrank(THJ);

        // Deploy core contracts
        queen = new HoneyQueen(address(0)); // Temporary zero address
        factory = new AdapterFactory(address(queen));
        locker = new HoneyLocker(address(factory), THJ, false);

        // Set factory in queen
        queen.setAdapterFactory(address(factory));

        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(address(queen), "HoneyQueen");
        vm.label(address(factory), "AdapterFactory");
        vm.label(address(locker), "HoneyLocker");
        vm.label(THJ, "THJ");
    }

    /*###############################################################
                            HELPERS
    ###############################################################*/

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }
}
