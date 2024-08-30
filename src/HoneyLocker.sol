// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";
import {HoneyQueen} from "./HoneyQueen.sol";
import {Beekeeper} from "./Beekeeper.sol";
import {TokenReceiver} from "./utils/TokenReceiver.sol";

/*
    The HoneyLocker is designed in such a way that it's multiple LP tokens
    but single deposit for each.
    The rationale is that Berachain is cheap enough that you can deploy
    multiple lockers if needed for multiple deposits of the same LP token.
*/
// prettier-ignore
contract HoneyLocker is TokenReceiver, Ownable {
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
    error WildcardFailed();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Initialized(address indexed owner);
    event Deposited(address indexed token, uint256 amount);
    event LockedUntil(address indexed token, uint256 expiration);
    event Staked(address indexed stakingContract, address indexed token, uint256 amount);
    event Unstaked(address indexed stakingContract, address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);
    event Migrated(address indexed token, address indexed oldLocker, address indexed newLocker);
    event RewardsClaimed(address stakingContract);
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

    modifier onlyOwnerOrMigratingVault() {
        if (msg.sender != owner() && owner() != Ownable(msg.sender).owner()) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrAutomaton() {
        if (msg.sender != owner() && msg.sender != HONEY_QUEEN.automaton()) revert Unauthorized();
        _;
    }

    modifier onlyUnblockedTokens(address _token) {
        if (!unlocked && HONEY_QUEEN.isTokenBlocked(_token)) revert TokenBlocked();
        _;
    }

    modifier onlyAllowedSelector(address _stakingContract, string memory action, bytes memory data) {
        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        if (!HONEY_QUEEN.isSelectorAllowedForTarget(selector, action, _stakingContract)) {
            revert SelectorNotAllowed();
        }
        _;
    }

    modifier onlyAllowedTargetContract(address _targetContract) {
        if (!HONEY_QUEEN.isTargetContractAllowed(_targetContract)) {
            revert TargetContractNotAllowed();
        }
        _;
    }
    /*###############################################################
                            INITIALIZER
    ###############################################################*/

    function initialize(address _owner, address _honeyQueen, address _referral, bool _unlocked) external {
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

    /// @notice Executes a wildcard function call on a target contract
    /// @notice A wildcard is for an "usual" function that is necessary but
    ///         doesn't fit in the stake/unstake/rewards categories
    /// @param _contract The address of the target contract
    /// @param _data The calldata to be sent to the target contract
    /// @custom:throws WildcardFailed if the call to the target contract fails
    function wildcard(address _contract, bytes calldata _data)
        external
        onlyOwner
        onlyAllowedTargetContract(_contract)
        onlyAllowedSelector(_contract, "wildcard", data)
    {
        (bool success,) = _contract.call(_data);
        if (!success) revert WildcardFailed();
    }

    /// @notice Stakes LP tokens in a staking contract
    /// @param _LPToken The address of the LP token to stake
    /// @param _stakingContract The address of the staking contract
    /// @param _amount The amount of LP tokens to stake
    /// @param _data The calldata to be sent to the staking contract
    /// @custom:throws StakeFailed if the call to the staking contract fails
    /// @custom:emits Staked event with the staking contract, LP token, and amount staked
    function stake(address _LPToken, address _stakingContract, uint256 _amount, bytes memory _data)
        external
        onlyOwner
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "stake", data)
    {
        staked[_LPToken][_stakingContract] += _amount;
        ERC20(_LPToken).approve(address(_stakingContract), _amount);
        (bool success,) = _stakingContract.call(_data);
        if (!success) revert StakeFailed();

        emit Staked(_stakingContract, _LPToken, _amount);
    }

    /// @notice Unstakes LP tokens from a staking contract
    /// @param _LPToken The address of the LP token to unstake
    /// @param _stakingContract The address of the staking contract
    /// @param _amount The amount of LP tokens to unstake
    /// @param _data The calldata to be sent to the staking contract
    /// @custom:throws UnstakeFailed if the call to the staking contract fails
    /// @custom:emits Unstaked event with the staking contract, LP token, and amount unstaked
    function unstake(address _LPToken, address _stakingContract, uint256 _amount, bytes memory _data)
        public
        onlyOwner
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "unstake", data)
    {
        staked[_LPToken][_stakingContract] -= _amount;
        (bool success,) = _stakingContract.call(_data);
        if (!success) revert UnstakeFailed();

        emit Unstaked(_stakingContract, _LPToken, _amount);
    }

    /// @notice Burns BGT tokens for BERA and withdraws the BERA
    /// @param _amount The amount of BGT to burn and BERA to withdraw
    function burnBGTForBERA(uint256 _amount) external onlyOwner {
        HONEY_QUEEN.BGT().redeem(address(this), _amount);
        withdrawBERA(_amount);
    }

    /// @notice Withdraws LP tokens from the HoneyLocker to the owner
    /// @dev The expiration time must have passed
    /// @param _LPToken The address of the LP token to withdraw
    /// @param _amount The amount of LP tokens to withdraw
    /// @custom:throws HasToBeLPToken if the token is not an LP token
    /// @custom:throws NotExpiredYet if the expiration time has not passed
    /// @custom:emits Withdrawn event with the LP token address and amount withdrawn
    function withdrawLPToken(address _LPToken, uint256 _amount) external onlyOwner {
        if (expirations[_LPToken] == 0) revert HasToBeLPToken();
        // only withdraw if expiration is OK
        if (block.timestamp < expirations[_LPToken]) revert NotExpiredYet();
        ERC20(_LPToken).transfer(msg.sender, _amount);
        emit Withdrawn(_LPToken, _amount);
    }

    /// @notice Migrates LP tokens to a new HoneyLocker contract
    /// @dev The migration must be enabled
    /// @param _LPTokens An array of LP token addresses to migrate
    /// @param _amountsOrIds An array of amounts or IDs corresponding to the LP tokens
    /// @param _newHoneyLocker The address of the new HoneyLocker contract
    /// @custom:throws MigrationNotEnabled if the migration is not enabled for the current and new contract
    /// @custom:emits Migrated event for each LP token migrated
    function migrate(address[] calldata _LPTokens, uint256[] calldata _amountsOrIds ,address payable _newHoneyLocker) external onlyOwner {
        // check migration is authorized based on codehashes
        if (!HONEY_QUEEN.isMigrationEnabled(address(this).codehash, _newHoneyLocker.codehash)) {
            revert MigrationNotEnabled();
        }

        for (uint256 i; i < _LPTokens.length; i++) {
            // send to new locker and deposit and lock
            ERC20(_LPTokens[i]).approve(address(_newHoneyLocker), _amountsOrIds[i]);
            HoneyLocker(_newHoneyLocker).depositAndLock(_LPTokens[i], _amountsOrIds[i], expirations[_LPTokens[i]]);

            emit Migrated(_LPTokens[i], address(this), _newHoneyLocker);
        }
    }

    /// @notice Claims rewards from a staking contract
    /// @dev Only the owner or automaton can call this function, and the staking contract and selector must be allowed
    /// @param _stakingContract The address of the staking contract
    /// @param _data The calldata to be sent to the staking contract
    /// @custom:throws ClaimRewardsFailed if the call to the staking contract fails
    /// @custom:emits RewardsClaimed event with the staking contract address
    function claimRewards(address _stakingContract, bytes memory _data)
        external
        onlyOwnerOrAutomaton
        onlyAllowedTargetContract(_stakingContract)
        onlyAllowedSelector(_stakingContract, "rewards", data)
    {
        (bool success,) = _stakingContract.call(_data);
        if (!success) revert ClaimRewardsFailed();
        emit RewardsClaimed(_stakingContract);
    }

    /// @notice Deposits and locks LP tokens in the HoneyLocker
    /// @dev Only the owner or migrating vault can call this function
    /// @param _LPToken The address of the LP token to deposit and lock
    /// @param _amountOrId The amount or ID of the LP token to deposit
    /// @param _expiration The expiration timestamp for the lock
    /// @custom:throws ExpirationNotMatching if the new expiration is less than the existing one for non-unlocked tokens
    /// @custom:emits Deposited event with the LP token address and amount or ID deposited
    /// @custom:emits LockedUntil event with the LP token address and expiration timestamp
    function depositAndLock(address _LPToken, uint256 _amountOrId, uint256 _expiration) external onlyOwnerOrMigratingVault {
        // we only allow subsequent deposits of the same token IF the
        // expiration is the same or greater
        if (!unlocked && expirations[_LPToken] != 0 && _expiration < expirations[_LPToken]) {
            revert ExpirationNotMatching();
        }
        // set expiration to 1 so token is marked as lp token
        expirations[_LPToken] = unlocked ? 1 : _expiration;
        // using transferFrom from ERC721 because same signature for ERC20
        // with the difference that ERC721 doesn't expect a return value
        ERC721(_LPToken).transferFrom(msg.sender, address(this), _amountOrId);

        emit Deposited(_LPToken, _amountOrId);
        emit LockedUntil(_LPToken, _expiration);
    }
    /*######################### BGT MANAGEMENT #########################*/

    function delegateBGT(uint128 _amount, address _validator) external onlyOwner {
        HONEY_QUEEN.BGT().queueBoost(_validator, _amount);
    }

    function activateBoost(address _validator) external onlyOwner {
        HONEY_QUEEN.BGT().activateBoost(_validator);
    }

    function cancelQueuedBoost(uint128 _amount, address _validator) external onlyOwner {
        HONEY_QUEEN.BGT().cancelBoost(_validator, _amount);
    }

    function dropBoost(uint128 _amount, address _validator) external onlyOwner {
        HONEY_QUEEN.BGT().dropBoost(_validator, _amount);
    }

    /*###############################################################*/
    function withdrawBERA(uint256 _amount) public onlyOwner {
        uint256 fees = HONEY_QUEEN.computeFees(_amount);
        STL.safeTransferETH(msg.sender, _amount - fees);
        HONEY_QUEEN.beekeeper().distributeFees{value: fees}(referral, address(0), fees);
        emit Withdrawn(address(0), _amount - fees);
    }

    function withdrawERC20(address _token, uint256 _amount) external onlyUnblockedTokens(_token) onlyOwner {
        // cannot withdraw any lp token that has an expiration
        if (expirations[_token] != 0) revert CannotBeLPToken();
        Beekeeper beekeeper = HONEY_QUEEN.beekeeper();
        uint256 fees = HONEY_QUEEN.computeFees(_amount);
        ERC20(_token).transfer(msg.sender, _amount - fees);
        ERC20(_token).transfer(address(beekeeper), fees);
        beekeeper.distributeFees(referral, _token, fees);
        emit Withdrawn(_token, _amount - fees);
    }

    function withdrawERC721(address _token, uint256 _id) external onlyUnblockedTokens(_token) onlyOwner {
        ERC721(_token).transferFrom(address(this), msg.sender, _id);
    }

    function withdrawERC1155(address _token, uint256 _id, uint256 _amount, bytes calldata data)
        external
        onlyUnblockedTokens(_token)
        onlyOwner
    {
        ERC1155(_token).safeTransferFrom(address(this), msg.sender, _id, _amount, data);
    }
    /*###############################################################
                            VIEW LOGIC
    ###############################################################*/
    /*###############################################################
                            PUBLIC LOGIC
    ###############################################################*/
    receive() external payable {}
}
