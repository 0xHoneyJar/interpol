// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {HoneyQueen} from "../src/HoneyQueen.sol";
import {Beekeeper} from "../src/Beekeeper.sol";
import {AdapterFactory} from "../src/AdapterFactory.sol";
import {LockerFactory} from "../src/LockerFactory.sol";

import {AdapterFactoryDeploy} from "./AdapterFactory.s.sol";
import {BeekeeperDeploy} from "./Beekeeper.s.sol";
import {HoneyQueenDeploy} from "./HoneyQueen.s.sol";
import {LockerFactoryDeploy} from "./LockerFactory.s.sol";
import {Config} from "./Config.sol";

contract DeployScript is Script {
    using stdJson for string;

    function setUp() public {}

    function run(bool isTestnet) public {
        HoneyQueenDeploy honeyQueenDeploy = new HoneyQueenDeploy();
        honeyQueenDeploy.run(isTestnet);
        
        BeekeeperDeploy beekeeperDeploy = new BeekeeperDeploy();
        beekeeperDeploy.run(isTestnet);
        
        AdapterFactoryDeploy adapterFactoryDeploy = new AdapterFactoryDeploy();
        adapterFactoryDeploy.run(isTestnet);

        LockerFactoryDeploy lockerFactoryDeploy = new LockerFactoryDeploy();
        lockerFactoryDeploy.run(isTestnet);

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pkey);

        HoneyQueen queen = honeyQueenDeploy.getHoneyQueen();
        AdapterFactory adapterFactory = adapterFactoryDeploy.getAdapterFactory();
        Beekeeper beekeeper = beekeeperDeploy.getBeekeeper();

        queen.setAdapterFactory(address(adapterFactory));
        queen.setBeekeeper(address(beekeeper));
        queen.setProtocolFees(200);

        vm.stopBroadcast();
    }
}