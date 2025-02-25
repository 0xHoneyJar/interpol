// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {HoneyQueenV2} from "../src/HoneyQueenV2.sol";
import {HoneyLockerV2} from "../src/HoneyLockerV2.sol";

contract UpdateScript is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pkey);

        Options memory options;
        options.referenceContract = "HoneyQueen.sol:HoneyQueen";
        Upgrades.upgradeProxy(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B, "HoneyQueenV2.sol:HoneyQueenV2", "", options);

        vm.stopBroadcast();
    }
}
