// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {HoneyQueenV2} from "../src/HoneyQueenV2.sol";
import {HoneyLockerV2} from "../src/HoneyLockerV2.sol";

contract UpdateScript is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pkey);

        // deploy new implementations for both honeyqueen and honeylocker
        // HoneyQueenV2 honeyQueenV2 = new HoneyQueenV2();
        // HoneyLockerV2 honeyLockerV2 = new HoneyLockerV2();

        HoneyQueenV2 honeyQueen = HoneyQueenV2(0x9f18D3bb7BB30581625d243FDB97Ab04f91FD95B);
        honeyQueen.upgradeToAndCall(0xCdDda6581E5FaDF74DEb583733417539c8812530, "");
        honeyQueen.setBadges(0x574617ab9788e614b3EB3F7Bd61334720d9E1Aac);


        vm.stopBroadcast();
    }
}
