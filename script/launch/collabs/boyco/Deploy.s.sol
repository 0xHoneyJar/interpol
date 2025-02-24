// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {BoycoInterpolVault} from "src/collabs/boyco/BoycoInterpolVault.sol";
import {HoneyQueen} from "src/HoneyQueen.sol";
import {LockerFactory} from "src/LockerFactory.sol";
import {HoneyLocker} from "src/HoneyLocker.sol";
import {Config} from "../../Config.sol";

import {IBGTStationGauge} from "src/adapters/BGTStationAdapter.sol";

contract Deploy is Script {
    using stdJson for string;

    BoycoInterpolVault public boycoInterpolVault;

    // <----- DEFINE ----->
    address public asset = 0x015fd589F4f1A33ce4487E12714e1B15129c9329;
    // <----- DEFINE ----->

    function setUp() public {}

    function run(bool isTestnet) public {

        Config config = new Config(isTestnet);

        string memory json = config.getConfig();

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);

        boycoInterpolVault = BoycoInterpolVault(payable(
            Upgrades.deployUUPSProxy(
                "BoycoInterpolVault.sol",
                abi.encodeCall(BoycoInterpolVault.initialize, (pubkey, address(0), address(0), address(0)))
            )
        ));

        vm.stopBroadcast();
    }
}
