// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {HoneyLockerV2} from "../src/HoneyLockerV2.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {HoneyQueenV2} from "../src/HoneyQueenV2.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {TokenReceiver} from "../src/utils/TokenReceiver.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {CUB} from "./mocks/CUB.sol";

abstract contract BaseTest is Test, TokenReceiver {
    /*###############################################################
                            CONSTANTS
    ###############################################################*/
    address internal THJ            = makeAddr("THJ");
    address internal THJTreasury    = makeAddr("THJTreasury");
    bytes   internal validator      = hex"4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7";

    address internal referrer       = makeAddr("referrer");
    address internal treasury       = makeAddr("treasury");
    address internal operator       = makeAddr("operator");

    IBGT    internal BGT            = IBGT(0x289274787bAF083C15A45a174b7a8e44F0720660);
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    HoneyLockerV2       public locker;
    HoneyQueenV2        public queen;
    Beekeeper           public beekeeper;
    LockerFactory       public lockerFactory;
    CUB                 public cub;

    string              public RPC_URL;
    string              public RPC_URL_ALT;
    string              public RPC_URL_MAINNET;

    constructor() {
        RPC_URL = vm.envOr(string("RPC_URL_TEST"), string("https://bartio.rpc.berachain.com/"));
        RPC_URL_ALT = vm.envOr(string("RPC_URL_TEST_ALT"), string(""));
        RPC_URL_MAINNET = vm.envOr(string("RPC_URL_MAINNET"), string(""));
    }
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual {
        vm.startPrank(THJ);

        cub = new CUB();
        cub.setTotalBadges(200);

        address queenImplementation = address(new HoneyQueenV2());
        bytes memory queenInitData = abi.encodeWithSelector(HoneyQueenV2.initialize.selector, THJ, address(BGT));
        queen = HoneyQueenV2(address(new ERC1967Proxy(queenImplementation, queenInitData)));

        beekeeper = new Beekeeper(THJ, THJTreasury);

        HoneyLockerV2 lockerImplementation = new HoneyLockerV2();
        address lockerBeacon = address(new UpgradeableBeacon(address(lockerImplementation), THJ));
        lockerFactory = new LockerFactory(address(queen), THJ);
        lockerFactory.setBeacon(lockerBeacon);

        locker = HoneyLockerV2(lockerFactory.createLocker(THJ, referrer, false));
        locker.setOperator(operator);

        queen.setBeekeeper(address(beekeeper));
        queen.setProtocolFees(200);
        queen.setBadges(address(cub));

        beekeeper.setReferrer(referrer, true);

        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(address(queen), "HoneyQueen");
        vm.label(address(locker), "HoneyLocker");
        vm.label(address(beekeeper), "Beekeeper");
        vm.label(THJ, "THJ");
        vm.label(address(BGT), "BGT");
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
