// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HoneyQueen} from "./HoneyQueen.sol";

interface IStakingContract {
    function stake(uint256 amount) external;
    function getReward(address account) external;
}

contract HoneyVault is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event DepsoitedAndLocked(address indexed token, uint256 amount);
    /*###############################################################
                            ENUMS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
    HoneyQueen internal HONEY_QUEEN;
    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    function initialize(address _owner, address _honeyQueen) external {
        require(owner() == address(0));
        _initializeOwner(_owner);
        HONEY_QUEEN = HoneyQueen(_honeyQueen);
    }
    /*###############################################################
                            OWNER LOGIC
    ###############################################################*/
    // prettier-ignore
    function depositAndLock(address _LPToken, uint256 _amount) external onlyOwner {
        IStakingContract stakeContract = IStakingContract(HONEY_QUEEN.LPTokenToStakeContract(_LPToken));
        require(address(stakeContract) != address(0), "HoneyQueen: LPToken not found");
        // need approval ??
        stakeContract.stake(_amount);
        emit DepsoitedAndLocked(_LPToken, _amount);
    }

    function burnBGTForBERA(uint256 _amount) external onlyOwner {
        HONEY_QUEEN.BGT().redeem(address(this), _amount);
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/

    /*
        Claims rewards, BGT, from the staking contract.
        The reward goes into the HoneyVault.
    */
    function claimRewards(address _LPToken) external {
        // prettier-ignore
        IStakingContract stakeContract = IStakingContract(HONEY_QUEEN.LPTokenToStakeContract(_LPToken));
        stakeContract.getReward(address(this));
    }

    function clone() external returns (address) {
        return LibClone.clone(address(this));
    }

    // prettier-ignore
    function cloneAndInitialize(address _initialOwner, address _honeyQueen) external returns (address) {
        address clone_ = LibClone.clone(address(this));
        HoneyVault(clone_).initialize(_initialOwner, _honeyQueen);
        return clone_;
    }
}
