// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {BoycoInterpolVaultV4} from "src/collabs/boyco/BoycoInterpolVaultV4.sol";

contract Update is Script {
    using stdJson for string;

    // <----- DEFINE ----->
    // <----- DEFINE ----->

    function setUp() public {}

    function run() public {

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);

        Options memory options;
        options.referenceContract = "BoycoInterpolVaultV3.sol:BoycoInterpolVaultV3";

        vm.startBroadcast(pkey);

        // deploy new implementation
        address newImplementation = Upgrades.deployImplementation(
            "BoycoInterpolVaultV4.sol",
            options
        );

        console.log("newImplementation", newImplementation);

        vm.stopBroadcast();
    }
}
