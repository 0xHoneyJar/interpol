// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {SetAndForgetFactory} from "../src/SetAndForgetFactory.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
}
// prettier-ignore

contract SetAndForgetTest is Test {
    using LibString for uint256;

    SetAndForgetFactory public factory;
    HoneyLocker public honeyLocker;
    HoneyQueen public honeyQueen;
    Beekeeper public beekeeper;
    uint256 public expiration;
    address public constant THJ = 0x4A8c9a29b23c4eAC0D235729d5e0D035258CDFA7;
    address public constant referral = address(0x5efe5a11);
    address public constant treasury = address(0x80085);
    string public constant PROTOCOL = "BGTSTATION";

    // IMPORTANT
    // BARTIO ADDRESSES
    // prettier-ignore
    ERC20 public constant HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    // prettier-ignore
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    // prettier-ignore
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bera-testnet.nodeinfra.com");
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        // prettier-ignore
        honeyQueen.setProtocolOfTarget(address(HONEYBERA_STAKING), PROTOCOL);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("stake(uint256)")), "stake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("withdraw(uint256)")), "unstake", PROTOCOL, true);
        honeyQueen.setIsSelectorAllowedForProtocol(bytes4(keccak256("getReward(address)")), "rewards", PROTOCOL, true);
        factory = new SetAndForgetFactory(address(honeyQueen));
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(msg.sender, "THJ");
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_singleDepositWithNoLock() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);

        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Deposited(address(HONEYBERA_LP), balance);
        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.LockedUntil(address(HONEYBERA_LP), expiration);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        assertEq(HONEYBERA_LP.balanceOf(address(honeyLocker)), balance);

        // withdraw lp tokens now
        honeyLocker.withdrawLPToken(address(HONEYBERA_LP), balance);
        assertEq(HONEYBERA_LP.balanceOf(THJ), balance);
        assertEq(HONEYBERA_LP.balanceOf(address(honeyLocker)), 0);
    }
}
