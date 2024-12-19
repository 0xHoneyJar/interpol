// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {RoycoInterpolVault} from "../../src/collabs/RoycoInterpolVault.sol";
import {HoneyQueen} from "../../src/HoneyQueen.sol";
import {LockerFactory} from "../../src/LockerFactory.sol";
import {Config} from "../Config.sol";

import {IBGTStationGauge} from "../../src/adapters/BGTStationAdapter.sol";

contract RoycoInterpolScript is Script {
    using stdJson for string;

    RoycoInterpolVault public roycoInterpolVault;

    // <----- DEFINE ----->
    address public asset;
    address public vault;
    address public validator;
    address public sfOperator;
    // <----- DEFINE ----->

    function setUp() public {}

    function run(bool isTestnet) public {
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        LockerFactory lockerFactory = LockerFactory(json.readAddress("$.lockerFactory"));
        address BGT = json.readAddress("$.BGT");
        HoneyQueen queen = HoneyQueen(json.readAddress("$.honeyqueen"));

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);

        address locker = lockerFactory.createLocker(pubkey, address(0), true);
        roycoInterpolVault = new RoycoInterpolVault(locker, asset, vault, BGT, validator);
        locker.setOperator(sfOperator);

        // Assume the deployer is the owner of HoneyQueen
        // if not, set the vault for the protocol elsewhere
        queen.setVaultForProtocol("BGTSTATION", vault, IBGTStationGauge(BGT).STAKE_TOKEN(), true);

        locker.registerAdapter("BGTSTATION");

        locker.transferOwnership(address(roycoInterpolVault));

        vm.stopBroadcast();

        vm.writeJson(vm.toString(address(beekeeper)), config.getConfigFilename(), ".beekeeper");
    }
}
