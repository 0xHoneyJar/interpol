// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {BoycoInterpolVault} from "../../src/collabs/boyco/BoycoInterpolVault.sol";
import {HoneyQueen} from "../../src/HoneyQueen.sol";
import {LockerFactory} from "../../src/LockerFactory.sol";
import {HoneyLocker} from "../../src/HoneyLocker.sol";
import {Config} from "../Config.sol";

import {IBGTStationGauge} from "../../src/adapters/BGTStationAdapter.sol";

contract BoycoInterpolScript is Script {
    using stdJson for string;

    BoycoInterpolVault public boycoInterpolVault;

    // <----- DEFINE ----->
    address public asset = 0x015fd589F4f1A33ce4487E12714e1B15129c9329;
    address public vault = 0x7D949A79259d55Da7da18EF947468B6E0b34f5cf;
    bytes   public validator = hex"49e7CF782fB697CDAe1046D45778C8aE3D7eC644";
    address public sfOperator = 0x16B58D5e5f78a85463fa6D7EcFf1aa010ab37E97;
    // <----- DEFINE ----->

    function setUp() public {}

    function run(bool isTestnet) public {
        if (asset == address(0) || vault == address(0) || sfOperator == address(0)) {
            revert("Missing parameters");
        }
        
        Config config = new Config(isTestnet);

        string memory json = config.getConfig();
        LockerFactory lockerFactory = LockerFactory(json.readAddress("$.lockerFactory"));
        address BGT = json.readAddress("$.BGT");
        HoneyQueen queen = HoneyQueen(json.readAddress("$.honeyqueen"));

        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address pubkey = vm.addr(pkey);
        vm.startBroadcast(pkey);

        address locker = lockerFactory.createLocker(pubkey, address(0), true);
        boycoInterpolVault = BoycoInterpolVault(payable(
            Upgrades.deployUUPSProxy(
                "BoycoInterpolVault.sol",
                abi.encodeCall(BoycoInterpolVault.initialize, (pubkey, locker, asset, vault))
            )
        ));
        boycoInterpolVault.setValidator(validator);
        HoneyLocker(payable(locker)).setOperator(sfOperator);

        // Assume the deployer is the owner of HoneyQueen
        // if not, set the vault for the protocol elsewhere
        queen.setVaultForProtocol("BGTSTATION", vault, IBGTStationGauge(BGT).stakeToken(), true);

        HoneyLocker(payable(locker)).registerAdapter("BGTSTATION");
        HoneyLocker(payable(locker)).wildcard(vault, 0, "");

        HoneyLocker(payable(locker)).transferOwnership(address(boycoInterpolVault));

        vm.stopBroadcast();
    }
}
