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
    address internal THJ        = makeAddr("THJ");
    address internal referrer   = makeAddr("referrer");
    address internal treasury   = makeAddr("treasury");
    address internal operator   = makeAddr("operator");
    address internal validator  = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    HoneyLocker     public locker;
    HoneyQueen      public queen;
    AdapterFactory  public factory;

    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual {
        vm.startPrank(THJ);

        // Deploy core contracts
        queen = new HoneyQueen(address(0)); // Temporary zero address
        factory = new AdapterFactory(address(queen));
        locker = new HoneyLocker(address(queen), THJ, referrer, false);
        locker.setOperator(operator);

        // Set factory in queen
        queen.setAdapterFactory(address(factory));

        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(address(queen), "HoneyQueen");
        vm.label(address(factory), "AdapterFactory");
        vm.label(address(locker), "HoneyLocker");
        vm.label(THJ, "THJ");
        vm.label(referrer, "referrer");
        vm.label(treasury, "treasury");
        vm.label(operator, "operator");
    }

    /*###############################################################
                            HELPERS
    ###############################################################*/

    modifier prankAsTHJ(bool _useOperator) {
        address user = _useOperator ? operator : THJ;
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }
}
