// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";

import {HoneyLocker} from "../../HoneyLocker.sol";
import {IBGTStationGauge} from "../../adapters/BGTStationAdapter.sol";

contract BoycoInterpolVault is ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using Math for uint256;
    /*###############################################################
                            STATE
    ###############################################################*/
    bytes       public                  validator;
    uint256     public                  totalSupplied;  // total usdc supplied through the bridge

    /*
        We expect this vault to be the owner of the locker (and therefore the default recipient)
        while the S&F operator is the operator of the locker.
    */
    HoneyLocker public        locker;         // locker deployed for this vault
    address     public        LPToken;        // LP token re-deposited by S&F operator
    address     public        vault;          // BGT Station vault

    address     public        asset;
    address     public        henlo;

    uint256[43] __gap;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    function initialize(
        address _owner,
        address _locker,
        address _asset,
        address _vault
    ) external initializer {
        ERC20Upgradeable.__ERC20_init("BoycoInterpolVault", "BOYCO-INTERPOL");
        __Ownable_init(_owner);
        // this vault should be the owner of the locker
        locker = HoneyLocker(payable(_locker));
        LPToken = IBGTStationGauge(_vault).stakeToken();
        vault = _vault;
        asset = _asset;
    }
    /*###############################################################
                            OWNER
    ###############################################################*/
    function setValidator(bytes memory _validator) public onlyOwner {
        validator = _validator;
    }
    function setHenlo(address _henlo) public onlyOwner {
        henlo = _henlo;
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/
    function _decimalsOffset() internal view virtual returns (uint8) {
        return 8;
    }
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function deposit(uint256 _assets, address _receiver) public returns (uint256) {
        uint256 shares = _assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalSupplied + 1, Math.Rounding.Floor);

        STL.safeTransferFrom(asset, msg.sender, address(this), _assets);
        totalSupplied += _assets;
        _mint(_receiver, shares);

        IERC20(asset).approve(address(locker), _assets);
        locker.depositAndLock(asset, _assets, 1);
        return shares;
    }

    function redeem(uint256 _shares, address _receiver) public returns (uint256) {
        uint256 LPBalance = locker.totalLPStaked(LPToken);
        uint256 henloBalance = IERC20(henlo).balanceOf(address(this));
        // also require that this vault has been set as the treasury in the locker
        uint256 LPToWithdraw = _shares.mulDiv(LPBalance + 1, totalSupply() + 10 ** _decimalsOffset(), Math.Rounding.Floor);
        uint256 henloToWithdraw = _shares.mulDiv(henloBalance + 1, totalSupply() + 10 ** _decimalsOffset(), Math.Rounding.Floor);

        _burn(msg.sender, _shares);

        locker.unstake(vault, LPToWithdraw);
        locker.withdrawLPToken(LPToken, LPToWithdraw);
        
        STL.safeTransfer(LPToken, _receiver, LPToWithdraw);
        STL.safeTransfer(henlo, _receiver, henloToWithdraw);

        return LPBalance;
    }

    receive() external payable {}

}
