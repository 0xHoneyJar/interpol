// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {AdapterFactory} from "../src/AdapterFactory.sol";
import {BGTStationAdapter} from "../src/adapters/BGTStationAdapter.sol";
import {InfraredAdapter} from "../src/adapters/InfraredAdapter.sol";
import {KodiakAdapter} from "../src/adapters/KodiakAdapter.sol";
import {BeradromeAdapter} from "../src/adapters/BeradromeAdapter.sol";
import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Config} from "./Config.sol";

contract AdaptersDeploy is Script {
    using stdJson for string;
    
    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        HoneyQueen queen = HoneyQueen(json.readAddress("$.honeyqueen"));
        uint256 pkey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pkey);

        // ---- BGTStation ----
        BGTStationAdapter bgtsAdapter = new BGTStationAdapter();
        queen.setAdapterForProtocol("BGTSTATION", address(bgtsAdapter));

        // ---- Infared ----
        InfraredAdapter infraredAdapter = new InfraredAdapter();
        queen.setAdapterForProtocol("INFRARED", address(infraredAdapter));

        // ---- Kodiak ----
        KodiakAdapter kodiakAdapter = new KodiakAdapter();
        queen.setAdapterForProtocol("KODIAK", address(kodiakAdapter));

        // ---- Beradrome ----
        BeradromeAdapter beradromeAdapter = new BeradromeAdapter();
        queen.setAdapterForProtocol("BERADROME", address(beradromeAdapter));

        vm.stopBroadcast();

        vm.writeJson(
            vm.toString(address(bgtsAdapter)),
            config.getConfigFilename(),
            ".adapters.BGTSTATION"
        );
        vm.writeJson(
            vm.toString(address(infraredAdapter)),
            config.getConfigFilename(),
            ".adapters.INFRARED"
        );
        vm.writeJson(
            vm.toString(address(kodiakAdapter)),
            config.getConfigFilename(),
            ".adapters.KODIAK"
        );
        vm.writeJson(
            vm.toString(address(beradromeAdapter)),
            config.getConfigFilename(),
            ".adapters.BERADROME"
        );
    }
}