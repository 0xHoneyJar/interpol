// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

import {BoycoInterpolVaultV2} from "../../../src/collabs/boyco/BoycoInterpolVaultV2.sol";

contract Update is Script {
    using stdJson for string;

    // <----- DEFINE ----->
    address public proxy = 0xC0ab623479371af246DD11872586720683B61e43;
    // <----- DEFINE ----->

    function setUp() public {}

    function run(bool isTestnet) public {

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);

        Options memory options;
        options.referenceContract = "BoycoInterpolVault.sol";

        vm.startBroadcast(pkey);

        Upgrades.upgradeProxy(
            address(proxy),
            "BoycoInterpolVaultV2.sol",
            "",
            options
        );

        vm.stopBroadcast();
    }
}
