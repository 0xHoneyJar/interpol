// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Script, console} from "forge-std/Script.sol";
// import {stdJson} from "forge-std/StdJson.sol";
// import {LockerFactory} from "../src/LockerFactory.sol";

// contract LockerFactoryDeploy is Script {
//     using stdJson for string;
//     function setUp() public {}

//     function run() public {
//         string memory json = vm.readFile("./script/config.json");
//         address honeyQueen = json.readAddress("$.honeyqueen");
//         uint256 pkey = vm.envUint("PRIVATE_KEY");
//         address pubkey = vm.addr(pkey);
//         vm.startBroadcast(pkey);
//         LockerFactory factory = new LockerFactory(honeyQueen);
//         vm.stopBroadcast();

//         vm.writeJson(
//             vm.toString(address(factory)),
//             "./script/config.json",
//             ".lockerFactory"
//         );
//     }
// }
