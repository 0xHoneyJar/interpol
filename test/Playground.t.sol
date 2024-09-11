// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Solarray as SLA} from "solarray/Solarray.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {HoneyLockerV2} from "./mocks/HoneyLockerV2.sol";
import {GaugeAsNFT} from "./mocks/GaugeAsNFT.sol";
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
    event ActivateBoost(address indexed sender, address indexed validator);
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

/*
    This test file tests all the functionnalities of the locker
    using the BEX LP Tokens on BGT Station only.
*/
// prettier-ignore
contract HoneyLockerTest is Test {
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

    ERC721 public constant KODIAK_V3 = ERC721(0xC0568C6E9D5404124c8AA9EfD955F3f14C8e64A6);

    function setUp() public {
        vm.createSelectFork("https://bartio.rpc.berachain.com/", uint256(4153762));
        expiration = block.timestamp + 30 days;

        vm.startPrank(THJ);
        beekeeper = new Beekeeper(THJ, treasury);
        beekeeper.setReferrer(referral, true);
        // setup honeyqueen stuff
        honeyQueen = new HoneyQueen(treasury, address(BGT), address(beekeeper));
        honeyQueen.setAutomaton(address(0xaaaa));
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

    function test_playground_depositKodiakV3() external {
        vm.startPrank(0xDe81B20B6801d99EFEaEcEd48a11ba025180b8cc);
        // new locker
        //honeyLocker = factory.clone(0xDe81B20B6801d99EFEaEcEd48a11ba025180b8cc, address(0));
        honeyLocker = HoneyLocker(payable(0x7435c4B7CaE9670dDc8cCd1d7193081E6f3A6807));
        // approve KodiakV3
        KODIAK_V3.approve(address(honeyLocker), 6658);
        // deposit
        honeyLocker.depositAndLock(address(KODIAK_V3), 6658, expiration);
        vm.stopPrank();
    }

}
