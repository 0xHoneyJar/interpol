// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";

import {HoneyLocker} from "../HoneyLocker.sol";
import {IBGTStationGauge} from "../adapters/BGTStationAdapter.sol";
import {IBGT} from "../utils/IBGT.sol";

contract RoycoInterpolVault is ERC4626 {
    /*###############################################################
                            STATE
    ###############################################################*/
    HoneyLocker public immutable    locker;
    address     public immutable    LPToken;        // LP token re-deposited by S&F operator
    address     public immutable    vault;
    address     public immutable    validator;      // validator S&F will delegate BGT to
    IBGT        public immutable    BGT;

    uint256                         assetSelector;  // 0: asset, 1: LPToken ; 2: BGT
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(
        address _locker,
        address _asset,
        address _vault,
        address _BGT,
        address _validator
    )
    ERC4626(IERC20(_asset))
    ERC20("RoycoInterpolVault", "ROYCO-INTERPOL") {
        // this vault should be the owner of the locker
        locker = HoneyLocker(payable(_locker));
        LPToken = IBGTStationGauge(_BGT).STAKE_TOKEN();
        vault = _vault;
        BGT = IBGT(_BGT);
        validator = _validator;
    }
    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/
    function totalAssets() public view override returns (uint256) {
        if (assetSelector == 1) {
            return locker.totalLPStaked(LPToken);
        } else if (assetSelector == 2) {
            address adapter = address(locker.adapterOfProtocol("BGTSTATION"));
            return BGT.balanceOf(adapter);
        } else {
            return super.totalAssets();
        }
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function deposit(uint256 _assets, address _receiver) public override returns (uint256) {
        uint256 shares = super.deposit(_assets, _receiver);
        IERC20(asset()).approve(address(locker), _assets);
        locker.depositAndLock(asset(), _assets, 1);
        return shares;
    }

    function redeem(uint256 _shares, address _receiver, address _owner) public override returns (uint256) {
        // get LP first
        assetSelector = 1;
        uint256 LPToWithdraw = previewRedeem(_shares);
        locker.unstake(vault, LPToWithdraw);
        locker.withdrawLPToken(asset(), LPToWithdraw);

        // get BGT (burned for BERA)
        assetSelector = 2;
        uint128 BGTToWithdraw = uint128(previewRedeem(_shares));
        {
            address adapter = address(locker.adapterOfProtocol("BGTSTATION"));
            (,uint128 queuedBGT) = BGT.boostedQueue(adapter, validator);

            uint128 BGTToCancel = BGTToWithdraw > queuedBGT ? queuedBGT : BGTToWithdraw;
            uint128 BGTToDrop = BGTToWithdraw - BGTToCancel;

            if (BGTToCancel > 0) BGT.cancelBoost(validator, BGTToCancel);
            if (BGTToDrop > 0) BGT.dropBoost(validator, BGTToDrop);
            locker.burnBGTForBERA(BGTToWithdraw);
        }
        assetSelector = 0;

        // burn part
        address caller = _msgSender();
        if (caller != _owner) {
            _spendAllowance(_owner, caller, _shares);
        }
        _burn(_owner, _shares);

        // transfer assets
        STL.safeTransfer(LPToken, _receiver, LPToWithdraw);
        STL.safeTransferETH(_receiver, BGTToWithdraw);

        // Because the asset withdrawn is not the same as the asset deposited
        // we get 0 of the original asset
        emit Withdraw(caller, _receiver, _owner, 0, _shares);
        return 0;

    }

    function withdraw(uint256 _shares, address _receiver, address _owner) public override returns (uint256) {
        revert();
    }

}