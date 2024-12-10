// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Script, console} from "forge-std/Script.sol";
// import {stdJson} from "forge-std/StdJson.sol";
// import {HoneyQueen} from "../src/HoneyQueen.sol";

// contract HoneyQueenDeploy is Script {
//     using stdJson for string;
//     function setUp() public {}

//     function run() public {
//         string memory json = vm.readFile("./script/config.json");
//         address treasury = json.readAddress("$.treasury");
//         address beekeeper = json.readAddress("$.beekeeper");

//         uint256 pkey = vm.envUint("PRIVATE_KEY");
//         address pubkey = vm.addr(pkey);
//         vm.startBroadcast(pkey);
//         address BGT = 0xbDa130737BDd9618301681329bF2e46A016ff9Ad;
//         HoneyQueen hq = new HoneyQueen(treasury, BGT, beekeeper);
//         vm.stopBroadcast();

//         vm.writeJson(vm.toString(address(hq)), "./script/config.json", ".honeyqueen");
//     }
// }
