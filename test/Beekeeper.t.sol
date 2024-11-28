// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HoneyLocker} from "../src/HoneyLocker.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {LockerFactory} from "../src/LockerFactory.sol";
import {IStakingContract} from "../src/utils/IStakingContract.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/*
    The Beekeeper tests exist in the contest of HoneyLocker use.
*/
// prettier-ignore
contract BeekeeperTest is Test {
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
        honeyLocker = HoneyLocker(payable(factory.clone(THJ, referral)));
        vm.stopPrank();

        vm.label(address(honeyLocker), "HoneyLocker");
        vm.label(address(honeyQueen), "HoneyQueen");
        vm.label(address(HONEYBERA_LP), "HONEYBERA_LP");
        vm.label(address(HONEYBERA_STAKING), "HONEYBERA_STAKING");
        vm.label(address(this), "Tests");
        vm.label(THJ, "THJ");
    }

    modifier prankAsTHJ() {
        vm.startPrank(THJ);
        _;
        vm.stopPrank();
    }

    function test_feesBERA() external prankAsTHJ {
        uint256 amountOfBera = 10e18;
        vm.deal(address(honeyLocker), amountOfBera);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amountOfBera.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(0), pythonReferrerFees);
        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(treasury, address(0), pythonTreasuryFees);
        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(0), pythonWithdrawn);

        uint256 balanceOfTHJBefore = THJ.balance;

        honeyLocker.withdrawBERA(amountOfBera);

        // check balances
        assertEq(address(treasury).balance, pythonTreasuryFees);
        assertEq(referral.balance, pythonReferrerFees);
        assertEq(THJ.balance, balanceOfTHJBefore + pythonWithdrawn);
    }

    function test_feesERC20() external prankAsTHJ {
        MockERC20 token = new MockERC20();
        uint256 amountOfToken = 10e18;
        token.mint(address(honeyLocker), amountOfToken);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amountOfToken.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(token), pythonReferrerFees);
        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(treasury, address(token), pythonTreasuryFees);
        vm.expectEmit(true, false, false, true, address(honeyLocker));
        emit HoneyLocker.Withdrawn(address(token), pythonWithdrawn);

        honeyLocker.withdrawERC20(address(token), amountOfToken);
    }

    function test_referrerOverride() external prankAsTHJ {
        address newReferrer = address(0x1234);
        beekeeper.setReferrerOverride(referral, newReferrer);

        uint256 amountOfBera = 10e18;
        vm.deal(address(honeyLocker), amountOfBera);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.standardReferrerFeeShare().toString();
        inputs[6] = "--amount";
        inputs[7] = amountOfBera.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(newReferrer, address(0), pythonReferrerFees);

        honeyLocker.withdrawBERA(amountOfBera);

        // check balances
        assertEq(newReferrer.balance, pythonReferrerFees);
        assertEq(referral.balance, 0);
    }

    function test_referrerFeeShare() external prankAsTHJ {
        beekeeper.setReferrerFeeShare(referral, 9000);

        uint256 amountOfBera = 10e18;
        vm.deal(address(honeyLocker), amountOfBera);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/fees.py";
        inputs[2] = "--fees-bps";
        inputs[3] = honeyQueen.fees().toString();
        inputs[4] = "--referrer-fees-bps";
        inputs[5] = beekeeper.referrerFeeShare(referral).toString();
        inputs[6] = "--amount";
        inputs[7] = amountOfBera.toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 pythonTreasuryFees, uint256 pythonReferrerFees, uint256 pythonWithdrawn) = abi.decode(res, (uint256, uint256, uint256));

        vm.expectEmit(true, true, false, true, address(beekeeper));
        emit Beekeeper.FeesDistributed(referral, address(0), pythonReferrerFees);

        honeyLocker.withdrawBERA(amountOfBera);

        // check balances
        assertEq(referral.balance, pythonReferrerFees);
    }
}
