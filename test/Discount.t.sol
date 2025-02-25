// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {LibString} from "solady/utils/LibString.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLockerV2} from "../src/HoneyLockerV2.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {IBGT} from "../src/utils/IBGT.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract DiscountTest is BaseTest {
    using LibString for uint256;
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public override {
        vm.createSelectFork(RPC_URL, uint256(7925685));
        super.setUp();
    }

    /*###############################################################
                            TESTS
    ###############################################################*/
    function test_discount(uint64 _amount, uint8 _badgesHeld) public {
        uint256 amount = uint256(StdUtils.bound(_amount, 1e16, type(uint64).max));
        _badgesHeld = uint8(StdUtils.bound(_badgesHeld, 0, 200));

        cub.setBadgesHeld(msg.sender, _badgesHeld);
        uint256 badgesPercentage = cub.badgesPercentageOfUser(msg.sender);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/utils/discount.py";
        inputs[2] = "--amount";
        inputs[3] = amount.toString();
        inputs[4] = "--badges-percentage";
        inputs[5] = badgesPercentage.toString();
        inputs[6] = "--protocol-fees";
        inputs[7] = queen.protocolFees().toString();
        bytes memory res = vm.ffi(inputs);
        (uint256 discountedAmount) = abi.decode(res, (uint256));

        uint256 computedFees = queen.computeFees(msg.sender, true, amount);
        uint256 computedFeesWithNoDiscount = queen.computeFees(msg.sender, false, amount);
        assertGe(computedFeesWithNoDiscount, computedFees);
        assertApproxEqRel(discountedAmount, computedFees, 1e15);
    }
}

