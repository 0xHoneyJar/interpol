// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {HoneyLocker} from "../src/HoneyLocker.sol";

contract Playground is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        // Config config = new Config(isTestnet);

        // string memory json = config.getConfig();

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);

        HoneyLocker locker = HoneyLocker(payable(0x5630177b639fb19507B56ca31c8B9c445FCd61EA));
        locker.setOperator(0xC0ab623479371af246DD11872586720683B61e43);

        vm.stopBroadcast();
    }
}
