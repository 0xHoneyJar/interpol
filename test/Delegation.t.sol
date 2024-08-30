// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
    event QueueBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event CancelBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event ActivateBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event DropBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );

    function minter() external view returns (address);
    function mint(address distributor, uint256 amount) external;
}

interface IBGTStaker {
    event Staked(address indexed staker, uint256 amount);
}

// prettier-ignore
contract DelegationTest is Test {
    using LibString for uint256;

    LockerFactory public factory;
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
    address public constant GOVERNANCE = 0xE3EDa03401Cf32010a9A9967DaBAEe47ed0E1a0b;
    ERC20 public constant HONEYBERA_LP = ERC20(0xd28d852cbcc68DCEC922f6d5C7a8185dBaa104B7);
    ERC20 public constant BGT = ERC20(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
    IBGTStaker public constant BGT_STAKER = IBGTStaker(0x791fb53432eED7e2fbE4cf8526ab6feeA604Eb6d);
    IStakingContract public HONEYBERA_STAKING = IStakingContract(0xAD57d7d39a487C04a44D3522b910421888Fb9C6d);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(1749904));
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
        honeyQueen.setValidator(THJ);
        factory = new LockerFactory(address(honeyQueen));
        honeyLocker = factory.clone(THJ, referral);
        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");
    }

    function mintBGT(address _to, uint256 _amount) public {
        vm.startPrank(IBGT(address(BGT)).minter());
        IBGT(address(BGT)).mint(_to, _amount);
        vm.stopPrank();
        vm.startPrank(THJ);
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_cancelQueuedBoost() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        uint256 bgtBalance = 10e18;
        // mint some BGT aka rewards, claim them which triggers boost queue
        mintBGT(address(honeyLocker), bgtBalance);
        // claiming rewards should trigger boost activation
        honeyLocker.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );

        // test the delegate part
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(honeyLocker), THJ, uint128(bgtBalance));
        honeyLocker.delegateBGT(uint128(bgtBalance), THJ);

        // test cancel boost
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.CancelBoost(address(honeyLocker), THJ, uint128(bgtBalance));
        honeyLocker.cancelQueuedBoost(uint128(bgtBalance), THJ);
    }

    function test_dropBoost() external prankAsTHJ {
        uint256 balance = HONEYBERA_LP.balanceOf(THJ);
        HONEYBERA_LP.approve(address(honeyLocker), balance);
        honeyLocker.depositAndLock(address(HONEYBERA_LP), balance, expiration);

        uint256 bgtBalance = 10e18;
        // mint some BGT aka rewards, claim them which triggers boost queue
        mintBGT(address(honeyLocker), bgtBalance);
        // claiming rewards should trigger boost activation
        honeyLocker.claimRewards(
            address(HONEYBERA_STAKING),
            abi.encodeWithSignature("getReward(address)", address(honeyLocker))
        );

        // test the delegate part
        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.QueueBoost(address(honeyLocker), THJ, uint128(bgtBalance));
        honeyLocker.delegateBGT(uint128(bgtBalance), THJ);

        vm.roll(block.timestamp + 10001);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.ActivateBoost(address(honeyLocker), THJ, uint128(bgtBalance));
        honeyLocker.activateBoost(THJ);

        vm.expectEmit(true, true, false, true, address(BGT));
        emit IBGT.DropBoost(address(honeyLocker), THJ, uint128(bgtBalance));
        honeyLocker.dropBoost(uint128(bgtBalance), THJ);

    }
}
