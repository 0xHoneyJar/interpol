// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {HoneyLockerV2} from "./mocks/HoneyLockerV2.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";
import {IBGT} from "./interfaces/IBGT.sol";

// prettier-ignore
contract POCTest is Test {
    using LibString for uint256;

    LockerFactory public factory;
    HoneyLocker public honeyLocker;
    HoneyQueen public honeyQueen;
    Beekeeper public beekeeper;
    
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);
    address public constant operator = address(0xaaaa);

    string public constant PROTOCOL = "BGTSTATION";

    // These addresses are for the BARTIO network
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    ERC20 public constant weHONEY_LP = ERC20(0x556b758AcCe5c4F2E1B57821E2dd797711E790F4);
    IStakingContract public weHONEY_GAUGE = IStakingContract(0x86DA232f6A4d146151755Ccf3e4555eadCc24cCF);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/");

        vm.startPrank(THJ);

        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);

        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        // prettier-ignore
        honeyQueen.setProtocolOfTarget(address(weHONEY_GAUGE), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdraw(uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);
        honeyQueen.setValidator(THJ);

        factory = new LockerFactory(address(honeyQueen));
        
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        honeyLocker.setOperator(operator);

        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(weHONEY_LP), "weHONEY_LP");
        vm.label(address(weHONEY_GAUGE), "weHONEY_GAUGE");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");


        // ---> EDIT IF NEEDED <---
        // Deal yourself LP tokens
        StdCheats.deal(address(weHONEY_LP), THJ, 1);

    }

    function test_POC() external {
    }

}
