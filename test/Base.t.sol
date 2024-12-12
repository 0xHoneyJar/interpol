// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {TokenReceiver} from "../src/utils/TokenReceiver.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {HoneyGuard} from "../src/HoneyGuard.sol";

abstract contract BaseTest is Test, TokenReceiver {
    /*###############################################################
                            CONSTANTS
    ###############################################################*/
    address internal THJ        = makeAddr("THJ");
    address internal referral   = makeAddr("referral");
    address internal treasury   = makeAddr("treasury");
    address internal operator   = makeAddr("operator");
    address internal validator  = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    IBGT    internal BGT        = IBGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    LockerFactory   internal factory;
    HoneyLocker     internal honeyLocker;
    HoneyQueen      internal honeyQueen;
    Beekeeper       internal beekeeper;
    HoneyGuard      internal honeyGuard;

    string          internal PROTOCOL;
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual {
        vm.startPrank(THJ);

        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);
        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        honeyQueen.setValidator(THJ);
        factory = new LockerFactory(address(honeyQueen));
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        honeyLocker.setOperator(operator);

        honeyGuard = new HoneyGuard(address(honeyQueen));
        honeyQueen.setHoneyGuard(address(honeyGuard));

        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");
        vm.label(referral, "referral");
        vm.label(treasury, "treasury");
        vm.label(operator, "operator");
    }

    /*###############################################################
                            HELPERS
    ###############################################################*/

    modifier prankAsTHJ(bool useOperator) {
        vm.startPrank(useOperator ? operator : THJ);
        // apply the prank once by making a random call
        try honeyQueen.setValidator(THJ) {} catch {}
        _;
        vm.stopPrank();
    }
}