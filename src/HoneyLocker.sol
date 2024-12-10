// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseVaultAdapter as BVA} from "./adapters/BaseVaultAdapter.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AdapterFactory} from "./AdapterFactory.sol";
import {IBGTStationGauge} from "./adapters/BGTStationAdapter.sol";
import {Constants} from "./Constants.sol";
contract HoneyLocker is Ownable {
    /*###############################################################
                            ERRORS
    ###############################################################*/
    error HoneyLocker__AdapterAlreadyRegistered();
    error HoneyLocker__AdapterNotFound();

    error HoneyLocker__ExpirationNotMatching();
    error HoneyLocker__HasToBeLPToken();
    error HoneyLocker__NotExpiredYet();
    error HoneyLocker__WithdrawalFailed();
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event VaultRegistered(
        address indexed vault,
        address indexed adapter,
        address logic
    );
    
    event Deposited(address indexed LPToken, uint256 amountOrId);
    event LockedUntil(address indexed LPToken, uint256 expiration);
    event Withdrawn(address indexed LPToken, uint256 amountOrId);

    event Staked(address indexed vault, address indexed LPToken, uint256 amountOrId);
    event Unstaked(address indexed vault, address indexed LPToken, uint256 amountOrId);
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(address vault => BVA adapter)   public              vaultToAdapter;
    AdapterFactory                          public immutable    factory;

    mapping(address LPToken => uint256 expiration) public expirations;
    bool                                           public unlocked;

    
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _factory, address _owner, bool _unlocked) {
        factory = AdapterFactory(_factory);
        _initializeOwner(_owner);
        unlocked = _unlocked;
    }
    /*###############################################################
                            MODIFIERS
    ###############################################################*/
    modifier onlyValidAdapter(address vault) {
        if (address(vaultToAdapter[vault]) == address(0)) revert HoneyLocker__AdapterNotFound();
        _;
    }
    /*###############################################################
                            OWNER
    ###############################################################*/
    /**
     * @notice              Registers a new vault adapter or overwrites an existing one
     * @param vault         The address of the vault to register
     * @param overwrite     Whether to overwrite an existing adapter
     *
     * @dev                 Creates a new adapter instance through the factory and maps it to the vault
     * @dev                 Will revert if adapter already exists and overwrite is false
     * @dev                 Only callable by owner
     */
    function registerVault(address vault, bool overwrite) external onlyOwner {
        BVA adapter = vaultToAdapter[vault];
        if (address(adapter) != address(0) && !overwrite) revert HoneyLocker__AdapterAlreadyRegistered();

        address newAdapter = factory.createAdapter(address(this), vault);
        
        vaultToAdapter[vault] = BVA(newAdapter);
    }

    /*###############################################################
                            VAULT MANAGEMENT
    ###############################################################*/
    function stake(address vault, uint256 amount) external onlyValidAdapter(vault) onlyOwner {
        BVA adapter = vaultToAdapter[vault];
        address token = adapter.stakingToken();

        ERC721(token).approve(address(adapter), amount);
        adapter.stake(amount);

        emit Staked(vault, token, amount);
    }

    function unstake(address vault, uint256 amount) external onlyValidAdapter(vault) onlyOwner {
        BVA adapter = vaultToAdapter[vault];
        adapter.unstake(amount);

        emit Unstaked(vault, adapter.stakingToken(), amount);
    }

    function claim(address vault) external onlyValidAdapter(vault) onlyOwner {
        BVA adapter = vaultToAdapter[vault];
        adapter.claim();
    }
    /*###############################################################
                            BGT MANAGEMENT
    ###############################################################*/
    function claimBGT(address vault) external onlyValidAdapter(vault) onlyOwner {
        BVA adapter = vaultToAdapter[vault];
        uint256 reward = IBGTStationGauge(vault).getReward(address(adapter));
        emit BVA.Claimed(address(this), vault, Constants.BGT, reward);
    }
    /*###############################################################
                            LP MANAGEMENT
    ###############################################################*/
    /// @notice Deposits and locks LP tokens in the HoneyLocker
    /// @dev Only the owner or migrating vault can call this function
    /// @param _LPToken The address of the LP token to deposit and lock
    /// @param _amountOrId The amount or ID of the LP token to deposit
    /// @param _expiration The expiration timestamp for the lock
    /// @custom:throws ExpirationNotMatching if the new expiration is less than the existing one for non-unlocked tokens
    /// @custom:emits Deposited event with the LP token address and amount or ID deposited
    /// @custom:emits LockedUntil event with the LP token address and expiration timestamp
    function depositAndLock(address _LPToken, uint256 _amountOrId, uint256 _expiration) external onlyOwner {

        if (!unlocked && expirations[_LPToken] != 0 && _expiration < expirations[_LPToken]) {
            revert HoneyLocker__ExpirationNotMatching();
        }

        expirations[_LPToken] = unlocked ? 0 : _expiration;

        // using transferFrom from ERC721 because same signature for ERC20
        // with the difference that ERC721 doesn't expect a return value
        ERC721(_LPToken).transferFrom(msg.sender, address(this), _amountOrId);

        emit Deposited(_LPToken, _amountOrId);
        emit LockedUntil(_LPToken, _expiration);
    }

    function withdrawLPToken(address _LPToken, uint256 _amountOrId) external onlyOwner {
        // if (HONEY_QUEEN.isRewardToken(_LPToken)) revert HasToBeLPToken();
        //if (expirations[_LPToken] == 0) revert HoneyLocker__HasToBeLPToken();
        if (block.timestamp < expirations[_LPToken]) revert HoneyLocker__NotExpiredYet();

        // self approval only needed for ERC20, try/catch in case it's an ERC721
        try ERC721(_LPToken).approve(address(this), _amountOrId) {} catch {}
        ERC721(_LPToken).transferFrom(address(this), msg.sender, _amountOrId);
        emit Withdrawn(_LPToken, _amountOrId);
    }
}
