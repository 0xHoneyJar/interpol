// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {stdJson} from "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";

contract Config is Script {
    using stdJson for string;

    bool internal isTestnet;

    constructor(bool _isTestnet) public {
        isTestnet = _isTestnet;
    }

    function getConfig() public view returns (string memory) {
        return vm.readFile(isTestnet ? "./script/testnet.config.json" : "./script/mainnet.config.json");
    }

    function getConfigFilename() public view returns (string memory) {
        return isTestnet ? "./script/testnet.config.json" : "./script/mainnet.config.json";
    }
}
