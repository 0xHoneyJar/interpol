// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";
import {HoneyQueen} from "./HoneyQueen.sol";
import {TokenReceiver} from "./TokenReceiver.sol";

import {Test, console} from "forge-std/Test.sol";

interface IStakingContract {
    event Staked(address indexed staker, uint256 amount);
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
    //function balanceOf(address account) external view returns (uint256);
    function exit() external;
}

/*
    The HoneyVault is designed in such a way that it's multiple LP tokens
    but single deposit for each.
    The rationale is that Berachain is cheap enough that you can deploy
    multiple vaults if needed for multiple deposits of the same LP token.
*/
contract HoneyVault is TokenReceiver, Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error MigrationNotEnabled();
    error AlreadyDeposited(address LPToken);
    error NotExpiredYet();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event DepositedAndLocked(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);
    event Migrated(
        address indexed token,
        address indexed oldVault,
        address indexed newVault
    );
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(address LPToken => uint256 balance) public balances;
    mapping(address LPToken => uint256 expiration) public expirations;
    HoneyQueen internal HONEY_QUEEN;
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
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

    // prettier-ignore
    function withdrawLPTokens(address _LPToken, uint256 _amount) external onlyOwner {
        // only withdraw if expiration is OK
        if (block.timestamp < expirations[_LPToken]) revert NotExpiredYet();
        IStakingContract stakingContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));

        stakingContract.withdraw(_amount);
        stakingContract.getReward(address(this));

        ERC20(_LPToken).transfer(msg.sender, _amount);

        emit Withdrawn(_LPToken, _amount);
    }

    // issue is that new honey vault could be a fake and unlock tokens
    // prettier-ignore
    function migrateLPToken(address _LPToken, address payable _newHoneyVault) external onlyOwner {
        // check migration is authorized based on codehashes
        if (!HONEY_QUEEN.isMigrationEnabled(address(this).codehash, _newHoneyVault.codehash)) {
            revert MigrationNotEnabled();
        }    
        IStakingContract stakingContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
        uint256 balance = balances[_LPToken];
        // empty balance
        balances[_LPToken] = 0;
        // get rewards and withdraw tokens at once
        stakingContract.exit();
        // send to new vault and deposit and lock
        ERC20(_LPToken).approve(address(_newHoneyVault), balance);
        HoneyVault(_newHoneyVault).depositAndLock(_LPToken, balance, expirations[_LPToken]);

        emit Migrated(_LPToken, address(this), _newHoneyVault);
    }

    function withdrawBERA(uint256 _amount) external onlyOwner {
        STL.safeTransferETH(owner(), _amount);
    }

    function rescueERC20(address _token, uint256 _amount) external onlyOwner {
        ERC20(_token).transfer(msg.sender, _amount);
    }
    function rescueERC721(address _token, uint256 _id) external onlyOwner {
        ERC721(_token).transferFrom(address(this), msg.sender, _id);
    }
    function rescueERC1155(
        address _token,
        uint256 _id,
        uint256 _amount,
        bytes calldata data
    ) external onlyOwner {
        ERC1155(_token).safeTransferFrom(
            address(this),
            msg.sender,
            _id,
            _amount,
            data
        );
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/

    /*
        So far this function and the reference in HoneyQueen expects the LP token
        to be a BEX one, which goes into BGT Station Gauges.
    */
    // prettier-ignore
    function depositAndLock(address _LPToken, uint256 _amount, uint256 _expiration) external {
        // only allow one deposit per lp token once!
        if (expirations[_LPToken] != 0) revert AlreadyDeposited(_LPToken);
        IStakingContract stakingContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
        // update balance
        balances[_LPToken] += _amount;
        expirations[_LPToken] = _expiration;

        ERC20(_LPToken).transferFrom(msg.sender, address(this), _amount);
        ERC20(_LPToken).approve(address(stakingContract), _amount);
        stakingContract.stake(_amount);

        emit DepositedAndLocked(_LPToken, _amount);
    }
    /*
        Claims rewards, BGT, from the staking contract.
        The reward goes into the HoneyVault.
    */
    function claimRewards(address _LPToken) external {
        // prettier-ignore
        IStakingContract stakingContract = IStakingContract(HONEY_QUEEN.LPTokenToStakingContract(_LPToken));
        stakingContract.getReward(address(this));
    }

    function clone() external returns (address) {
        return LibClone.clone(address(this));
    }

    // prettier-ignore
    function cloneAndInitialize(address _initialOwner, address _honeyQueen) external returns (address) {
        address payable clone_ = payable(LibClone.clone(address(this)));
        HoneyVault(clone_).initialize(_initialOwner, _honeyQueen);
        return clone_;
    }

    receive() external payable {}
}
