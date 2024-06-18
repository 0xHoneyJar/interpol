// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HoneyQueen} from "./HoneyQueen.sol";

interface IStakingContract {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
    function balanceOf(address account) external view returns (uint256);
}

contract HoneyVault is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event DepositedAndLocked(address indexed token, uint256 amount);
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
    function burnBGTForBERA(uint256 _amount) external onlyOwner {
        HONEY_QUEEN.BGT().redeem(address(this), _amount);
    }

    // issue is that new honey vault could be a fake and unlock tokens
    // prettier-ignore
    function migrateLPToken(address _LPToken, address _newHoneyVault) external onlyOwner {
        // check migration is authorized based on codehashes
        require(
            HONEY_QUEEN.isMigrationEnabled(address(this).codehash, _newHoneyVault.codehash),
            "HoneyQueen: Migration is not enabled"
        );
        IStakingContract stakeContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
        uint256 balance = stakeContract.balanceOf(address(this));
        // get rewards before migrating
        stakeContract.getReward(address(this));
        // withdraw
        stakeContract.withdraw(balance);
        // send to new vault and deposit and lock
        HoneyVault(_newHoneyVault).depositAndLock(_LPToken, balance);
    }

    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/

    // prettier-ignore
    function depositAndLock(address _LPToken, uint256 _amount) external {
        IStakingContract stakeContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
        require(address(stakeContract) != address(0), "HoneyQueen: LPToken not found");
        // need approval ??
        stakeContract.stake(_amount);
        emit DepositedAndLocked(_LPToken, _amount);
    }

    /*
        Claims rewards, BGT, from the staking contract.
        The reward goes into the HoneyVault.
    */
    function claimRewards(address _LPToken) external {
        // prettier-ignore
        IStakingContract stakeContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
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
