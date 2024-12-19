// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {HoneyLocker} from "../HoneyLocker.sol";

contract RoycoInterpolVault is ERC4626 {
    /*###############################################################
                            STATE
    ###############################################################*/
    HoneyLocker public locker;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _locker, address _asset)
    ERC4626(IERC20(_asset))
    ERC20("RoycoInterpolVault", "ROYCO-INTERPOL") {
        locker = HoneyLocker(payable(_locker));
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function deposit(uint256 _assets, address _receiver) public override returns (uint256) {
        locker.depositAndLock(asset(), _assets, 1);
        return super.deposit(_assets, _receiver);
    }

    function redeem(uint256 _shares, address _receiver, address _owner) public override returns (uint256) {
        locker.withdrawLPToken(asset(), _shares);
        return super.redeem(_shares, _receiver, _owner);
    }

    function withdraw(uint256 _shares, address _receiver, address _owner) public override returns (uint256) {
        revert();
    }

}