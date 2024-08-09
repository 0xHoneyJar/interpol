// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";
import {HoneyQueen} from "./HoneyQueen.sol";
import {TokenReceiver} from "./utils/TokenReceiver.sol";
import {IBGT} from "./utils/IBGT.sol";

/*
    The HoneyVault is designed in such a way that it's multiple LP tokens
    but single deposit for each.
    The rationale is that Berachain is cheap enough that you can deploy
    multiple vaults if needed for multiple deposits of the same LP token.
*/
// prettier-ignore
contract HoneyVault is TokenReceiver, Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error MigrationNotEnabled();
    error ExpirationNotMatching();
    error TargetContractNotAllowed();
    error NotExpiredYet();
    error TokenBlocked();
    error CannotBeLPToken();
    error HasToBeLPToken();
    error StakeFailed();
    error UnstakeFailed();
    error SelectorNotAllowed();
    error ClaimRewardsFailed();
    error NotEnoughBoostedToBurn();
    error WildcardFailed();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Initialized(address indexed owner);
    event Deposited(address indexed token, uint256 amount);
    event LockedUntil(address indexed token, uint256 expiration);
    event Staked(
        address indexed stakingContract,
        address indexed token,
        uint256 amount
    );
    event Unstaked(
        address indexed stakingContract,
        address indexed token,
        uint256 amount
    );
    event Withdrawn(address indexed token, uint256 amount);
    event Migrated(
        address indexed token,
        address indexed oldVault,
        address indexed newVault
    );
    event Fees(address indexed referral, address token, uint256 amount);
    /*###############################################################
                            STRUCTS
    ###############################################################*/
    /*###############################################################
                            STORAGE
    ###############################################################*/
   
    // tracks amount of tokens staked per staking contract
    mapping(address LPToken => mapping(address stakingContract => uint256 balance)) public staked;
    mapping(address LPToken => uint256 expiration) public expirations;
    address public referral;
    bool public unlocked; // whether contract should not or should enforce restrictions
    HoneyQueen internal HONEY_QUEEN;
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    modifier onlyUnblockedTokens(address _token) {
        if (!unlocked && HONEY_QUEEN.isTokenBlocked(_token)) revert TokenBlocked();
        _;
    }

    modifier onlyAllowedSelector(
        address _stakingContract,
        string memory action,
        bytes memory data
    ) {
        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        if (!HONEY_QUEEN.isSelectorAllowedForTarget(selector, action, _stakingContract))
            revert SelectorNotAllowed();
        _;
    }

    modifier onlyAllowedTargetContract(address _targetContract) {
        if (!HONEY_QUEEN.isTargetContractAllowed(_targetContract))
            revert TargetContractNotAllowed();
        _;
    }
    /*###############################################################
                            INITIALIZER
    ###############################################################*/
    function initialize(
        address _owner,
        address _honeyQueen,
        address _referral,
        bool _unlocked
    ) external {
        require(address(HONEY_QUEEN) == address(0));
        _initializeOwner(_owner);
        HONEY_QUEEN = HoneyQueen(_honeyQueen);
        referral = _referral;
        unlocked = _unlocked;

        emit Initialized(_owner);
    }
    /*###############################################################
                            OWNER LOGIC
    ###############################################################*/

    function wildcard(
        address _contract,
        bytes calldata data
    )
        external
        onlyOwner
        onlyAllowedTargetContract(_contract)
        onlyAllowedSelector(_contract, "wildcard", data)
    {
        (bool success, ) = _contract.call(data);
        if (!success) revert WildcardFailed();
    }

    function stake(
        address _LPToken,
        address _stakingContract,
        uint256 _amount,
        bytes memory data
    )
        external
        onlyOwner
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "stake", data)
    {
        staked[_LPToken][_stakingContract] += _amount;
        ERC20(_LPToken).approve(address(_stakingContract), _amount);
        (bool success, ) = _stakingContract.call(data);
        if (!success) revert StakeFailed();

        emit Staked(_stakingContract, _LPToken, _amount);
    }

    function unstake(
        address _LPToken,
        address _stakingContract,
        uint256 _amount,
        bytes memory data
    )
        public
        onlyOwner
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "unstake", data)
    {
        staked[_LPToken][_stakingContract] -= _amount;
        (bool success, ) = _stakingContract.call(data);
        if (!success) revert UnstakeFailed();

        emit Unstaked(_stakingContract, _LPToken, _amount);
    }

    /*
        Bundle redeeming and withdrawing together.
        Reasoning is that no practical use case where user wants to
        leave BERA into the vault after redeeming.

        Since BGT rewards are automatically boosted, we have to
        drop the boost for the amount we want to convert.
        For simplicity, we don't try to cancel queued boosts.
    */
    function burnBGTForBERA(uint256 _amount) external onlyOwner {
        IBGT BGT = HONEY_QUEEN.BGT();
        uint256 boosted = BGT.boosted(address(this), HONEY_QUEEN.validator());
        (,uint256 queued) = BGT.boostedQueue(address(this), HONEY_QUEEN.validator());

        if (boosted + queued < _amount)
            revert NotEnoughBoostedToBurn();

        uint256 amountToDrop = boosted >= _amount ? _amount : boosted;
        uint256 amountToCancel = _amount - amountToDrop;

        if (amountToDrop > 0) BGT.dropBoost(HONEY_QUEEN.validator(), uint128(amountToDrop));

        if (amountToCancel > 0) BGT.cancelBoost(HONEY_QUEEN.validator(), uint128(amountToCancel));

        BGT.redeem(address(this), _amount);
        withdrawBERA(_amount);
    }

    /*
        Unrelated to staking contracts or gauges withdrawal.
        This only sends tokens held by the HoneyVault to the owner.
    */
    function withdrawLPToken(address _LPToken, uint256 _amount) external onlyOwner {
        if (expirations[_LPToken] == 0) revert HasToBeLPToken();
        // only withdraw if expiration is OK
        if (block.timestamp < expirations[_LPToken]) revert NotExpiredYet();
        ERC20(_LPToken).transfer(msg.sender, _amount);
        emit Withdrawn(_LPToken, _amount);
    }

    // issue is that new honey vault could be a fake and unlock tokens
    // assumption is that user unstaked before
    function migrate(address[] calldata _LPTokens, address payable _newHoneyVault) external onlyOwner {
        // check migration is authorized based on codehashes
        if (!HONEY_QUEEN.isMigrationEnabled(address(this).codehash, _newHoneyVault.codehash)) {
            revert MigrationNotEnabled();
        }
        for (uint256 i; i < _LPTokens.length; i++) {
            uint256 balance = ERC20(_LPTokens[i]).balanceOf(address(this));
            // send to new vault and deposit and lock
            ERC20(_LPTokens[i]).approve(address(_newHoneyVault), balance);
            HoneyVault(_newHoneyVault).depositAndLock(_LPTokens[i], balance, expirations[_LPTokens[i]]);

            emit Migrated(_LPTokens[i], address(this), _newHoneyVault);
        }
    }

    function delegateBGT(uint128 _amount, address _validator) external onlyOwner {
        HONEY_QUEEN.BGT().queueBoost(_validator, _amount);
    }

    /*###############################################################*/
    function withdrawBERA(uint256 _amount) public onlyOwner {
        address treasury = HONEY_QUEEN.treasury();
        uint256 fees = HONEY_QUEEN.computeFees(_amount);
        STL.safeTransferETH(treasury, fees);
        STL.safeTransferETH(msg.sender, _amount - fees);
        /*!*/ emit Withdrawn(address(0), _amount - fees);
        /*!*/ emit Fees(referral, address(0), fees);
    }

    function withdrawERC20(
        address _token,
        uint256 _amount
    ) external onlyUnblockedTokens(_token) onlyOwner {
        // cannot withdraw any lp token that has an expiration
        if (expirations[_token] != 0) revert CannotBeLPToken();
        address treasury = HONEY_QUEEN.treasury();
        uint256 fees = HONEY_QUEEN.computeFees(_amount);
        ERC20(_token).transfer(treasury, fees);
        ERC20(_token).transfer(msg.sender, _amount - fees);
        /*!*/ emit Withdrawn(_token, _amount - fees);
        /*!*/ emit Fees(referral, _token, fees);
    }

    function withdrawERC721(
        address _token,
        uint256 _id
    ) external onlyUnblockedTokens(_token) onlyOwner {
        ERC721(_token).transferFrom(address(this), msg.sender, _id);
    }

    function withdrawERC1155(
        address _token,
        uint256 _id,
        uint256 _amount,
        bytes calldata data
    ) external onlyUnblockedTokens(_token) onlyOwner {
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

    function depositAndLock(
        address _LPToken,
        uint256 _amount,
        uint256 _expiration
    ) external {
        // we only allow subsequent deposits of the same token IF the
        // expiration is the same
        if (!unlocked && expirations[_LPToken] != 0 && _expiration != expirations[_LPToken])
            revert ExpirationNotMatching();
        // set expiration to 1 so token is marked as lp token
        expirations[_LPToken] = unlocked ? 1 : _expiration;
        // tokens have to be transfered to have accurate balance tracking
        ERC20(_LPToken).transferFrom(msg.sender, address(this), _amount);

        emit Deposited(_LPToken, _amount);
        emit LockedUntil(_LPToken, _expiration);
    }

    /*
        Claims rewards, BGT, from the staking contract.
        The reward goes into the HoneyVault.
    */
    function claimRewards(
        address _stakingContract,
        bytes memory data
    )
        external
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "rewards", data)
    {
        (bool success, ) = _stakingContract.call(data);
        if (!success) revert ClaimRewardsFailed();
    }

    function activateBoost(address _validator) external {
        HONEY_QUEEN.BGT().activateBoost(_validator);
    }

    receive() external payable {}
}
