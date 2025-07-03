// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BaseTest} from "./Base.t.sol";
import {HoneyLockerV4} from "../src/HoneyLockerV4.sol";
import {BGTStationAdapterV3, IBGTStationGauge} from "../src/adapters/BGTStationAdapterV3.sol";
import {BaseVaultAdapter as BVA} from "../src/adapters/BaseVaultAdapter.sol";
import {IInfrared} from "../src/utils/IInfrared.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract InfraredBGTTest is BaseTest {    
    /*###############################################################
                            STATE VARIABLES
    ###############################################################*/
    BGTStationAdapterV3     public adapter;
    BVA                     public lockerAdapter;   // adapter for BGT Station used by locker

    // BERA-HONEY gauge
    address     public constant GAUGE           = 0xC2BaA8443cDA8EBE51a640905A8E6bc4e1f9872c;
    // BERA-HONEY LP token
    ERC20       public constant LP_TOKEN        = ERC20(0x2c4a603A2aA5596287A06886862dc29d56DbC354);

    address     public constant INFRARED        = 0xb71b3DaEA39012Fb0f2B14D2a9C86da9292fC126;
    address     public constant INFRARED_BGT    = 0xac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b;
    /*###############################################################
                            SETUP
    ###############################################################*/
    function setUp() public virtual override {
        /*
            Choosing this block number because the vault LBGT-WBERA is active
        */
        vm.createSelectFork(RPC_URL_MAINNET);

        super.setUp();

        // Deploy adapter implementation that will be cloned
        address adapterLogic = address(new BGTStationAdapterV3());
        address adapterBeacon = address(new UpgradeableBeacon(adapterLogic, THJ));

        vm.startPrank(THJ);

        queen.setAdapterBeaconForProtocol("BGTSTATION", address(adapterBeacon));
        queen.setVaultForProtocol("BGTSTATION", GAUGE, address(LP_TOKEN), true);
        locker.registerAdapter("BGTSTATION");

        queen.setInfrared(INFRARED);
        queen.setInfraredBGT(INFRARED_BGT);

        //locker.wildcard(address(GAUGE), 0, "");

        lockerAdapter = BVA(locker.adapterOfProtocol("BGTSTATION"));

        vm.stopPrank();

        vm.label(address(lockerAdapter), "BGTStationAdapter");
        vm.label(address(adapterBeacon), "BGTStationBeacon");
        vm.label(address(adapterLogic), "BGTStationLogic");
        vm.label(address(GAUGE), "BERA-HONEY Gauge");
        vm.label(address(LP_TOKEN), "BERA-HONEY LP Token");
    }

    /*###############################################################
                            TESTS
    ###############################################################*/

    function test_claimRewards() external prankAsTHJ(false) {
        uint256 amountToDeposit = 100 ether;

        StdCheats.deal(address(LP_TOKEN), address(locker), amountToDeposit);

        locker.stake(address(GAUGE), amountToDeposit);

        vm.warp(block.timestamp + 10000);

        locker.wildcard(address(GAUGE), 0, "");

        // check balance of iBGT that should be greater than 0
        assertGt(ERC20(INFRARED_BGT).balanceOf(address(locker)), 0);
    }
}


