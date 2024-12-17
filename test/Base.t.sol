// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {console2} from "forge-std/console2.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {AdapterFactory} from "../src/AdapterFactory.sol";
import {TokenReceiver} from "../src/utils/TokenReceiver.sol";
import {IBGT} from "../src/utils/IBGT.sol";

abstract contract BaseTest is Test, TokenReceiver {
    /*###############################################################
                            CONSTANTS
    ###############################################################*/
    address internal THJ        = makeAddr("THJ");
    address internal THJTreasury = makeAddr("THJTreasury");
    address internal validator  = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;

    address internal referrer   = makeAddr("referrer");
    address internal treasury   = makeAddr("treasury");
    address internal operator   = makeAddr("operator");

    IBGT    internal BGT        = IBGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    HoneyLocker     public locker;
    HoneyQueen      public queen;
    AdapterFactory  public factory;
    Beekeeper       public beekeeper;
    
    string          public RPC_URL;

    constructor() {
        RPC_URL = vm.envOr(string("RPC_URL"), string("https://bartio.rpc.berachain.com/"));
    }
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual {
        vm.startPrank(THJ);

        queen = new HoneyQueen(address(BGT), address(0)); // Temporary zero address
        beekeeper = new Beekeeper(THJ, THJTreasury);
        factory = new AdapterFactory(address(queen));
        locker = new HoneyLocker(address(queen), THJ, referrer, false);

        locker.setOperator(operator);

        queen.setAdapterFactory(address(factory));
        queen.setBeekeeper(address(beekeeper));
        queen.setProtocolFees(200);

        beekeeper.setReferrer(referrer, true);

        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(address(queen), "HoneyQueen");
        vm.label(address(factory), "AdapterFactory");
        vm.label(address(locker), "HoneyLocker");
        vm.label(address(beekeeper), "Beekeeper");
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
