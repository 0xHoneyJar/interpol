// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";

contract Beekeeper is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error NotAReferrer();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event FeesDistributed(address indexed recipient, address indexed token, uint256 amount);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    address public treasury;
    uint256 public standardReferrerFeeShare = 3000; // 30%
    mapping(address referrer => bool authorized) public isReferrer;
    mapping(address referrer => address overridingReferrer) public referrerOverrides;
    mapping(address referrer => uint256 shareOfFeeInBps) public referrerFeeShare;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _owner, address _treasury) {
        _initializeOwner(_owner);
        treasury = _treasury;
    }
    /*###############################################################
                            OWNER ONLY
    ###############################################################*/
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
    function setStandardReferrerFeeShare(uint256 _standardReferrerFeeShare) external onlyOwner {
        standardReferrerFeeShare = _standardReferrerFeeShare;
    }
    function setReferrer(address _referrer, bool _isReferrer) external onlyOwner {
        isReferrer[_referrer] = _isReferrer;
    }
    /*
        The referrer override is to be used if the original referrer address private key is compromised.
        The overriding referrer will receive the fees instead of the original referrer.
        The original referrer HAS to be maintained as a valid referrer.
    */
    function setReferrerOverride(address _referrer, address _overridingReferrer) external onlyOwner {
        if (!isReferrer[_referrer]) revert NotAReferrer();
        referrerOverrides[_referrer] = _overridingReferrer;
    }
    function setReferrerFeeShare(address _referrer, uint256 _shareOfFeeInBps) external onlyOwner {
        if (!isReferrer[_referrer]) revert NotAReferrer();
        referrerFeeShare[_referrer] = _shareOfFeeInBps;
    }
    /*###############################################################
                            INTERNAL ONLY
    ###############################################################*/
    /*###############################################################
                            EXTERNAL
    ###############################################################*/
    function distributeFees(address _referrer, address _token, uint256 _amount) external payable {
        bool isBera = _token == address(0);
        // if not an authorized referrer, send everything to treasury
        if (!isReferrer[_referrer]) {
            isBera ? STL.safeTransferETH(treasury, _amount) : STL.safeTransfer(_token, treasury, _amount);
            emit FeesDistributed(treasury, _token, _amount);
            return;
        }
        address referrer = referrerOverrides[_referrer] != address(0) ? referrerOverrides[_referrer] : _referrer;
        // if no specified referrer fee share, use the standard one
        uint256 referrerFeeShareInBps = referrerFeeShare[referrer] != 0 ? referrerFeeShare[referrer] : standardReferrerFeeShare;
        uint256 referrerFee = (_amount * referrerFeeShareInBps) / 10000;

        isBera ? STL.safeTransferETH(referrer, referrerFee) : STL.safeTransfer(_token, referrer, referrerFee);
        isBera ? STL.safeTransferETH(treasury, _amount - referrerFee) : STL.safeTransfer(_token, treasury, _amount - referrerFee);

        emit FeesDistributed(referrer, _token, referrerFee);
        emit FeesDistributed(treasury, _token, _amount - referrerFee);
    }
}