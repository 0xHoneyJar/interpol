// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {BGTStationAdapter} from "src/adapters/BGTStationAdapter.sol";
import {InfraredAdapter} from "src/adapters/InfraredAdapter.sol";
import {KodiakAdapter} from "src/adapters/KodiakAdapter.sol";
import {BeradromeAdapter} from "src/adapters/BeradromeAdapter.sol";
import {HoneyQueen} from "src/HoneyQueen.sol";
import {Config} from "./Config.sol";

contract AdaptersDeploy is Script {
    using stdJson for string;
    
    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        HoneyQueen queen = HoneyQueen(json.readAddress("$.honeyqueen"));
        address owner = json.readAddress("$.owner");
        uint256 pkey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pkey);

        // ---- BGTStation ----
        address bgtBeacon = Upgrades.deployBeacon("BGTStationAdapter.sol:BGTStationAdapter", owner);
        queen.setAdapterBeaconForProtocol("BGTSTATION", bgtBeacon);

        // ---- Infared ----
        address infraredBeacon = Upgrades.deployBeacon("InfraredAdapter.sol:InfraredAdapter", owner);
        queen.setAdapterBeaconForProtocol("INFRARED", infraredBeacon);

        // ---- Kodiak ----
        address kodiakBeacon = Upgrades.deployBeacon("KodiakAdapter.sol:KodiakAdapter", owner);
        queen.setAdapterBeaconForProtocol("KODIAK", kodiakBeacon);

        // ---- Beradrome ----
        address beradromeBeacon = Upgrades.deployBeacon("BeradromeAdapter.sol:BeradromeAdapter", owner);
        queen.setAdapterBeaconForProtocol("BERADROME", beradromeBeacon);

        vm.stopBroadcast();

        vm.writeJson(
            vm.toString(bgtBeacon),
            config.getConfigFilename(),
            ".adapters.BGTSTATION"
        );
        vm.writeJson(
            vm.toString(infraredBeacon),
            config.getConfigFilename(),
            ".adapters.INFRARED"
        );
        vm.writeJson(
            vm.toString(kodiakBeacon),
            config.getConfigFilename(),
            ".adapters.KODIAK"
        );
        vm.writeJson(
            vm.toString(beradromeBeacon),
            config.getConfigFilename(),
            ".adapters.BERADROME"
        );
        console.log("BGTStation beacon deployed at", bgtBeacon);
        console.log("Infrared beacon deployed at", infraredBeacon);
        console.log("Kodiak beacon deployed at", kodiakBeacon);
        console.log("Beradrome beacon deployed at", beradromeBeacon);
    }
}
