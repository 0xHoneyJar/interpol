pragma solidity ^0.8.23;

interface IBGT {
    event Redeem(address indexed from, address indexed receiver, uint256 amount);
    event QueueBoost(address indexed sender, address indexed validator, uint128 amount);
    event CancelBoost(address indexed sender, address indexed validator, uint128 amount);
    event ActivateBoost(address indexed sender, address indexed validator, uint128 amount);
    event DropBoost(address indexed sender, address indexed validator, uint128 amount);
    
    function redeem(address receiver, uint256 amount) external;
    function queueBoost(address validator, uint128 amount) external;
    function cancelBoost(address validator, uint128 amount) external;
    function activateBoost(address validator) external;
    function dropBoost(address validator, uint128 amount) external;
    function unboostedBalanceOf(address account) external view returns (uint256);
    function boosted(address account, address validator) external view returns (uint128);
    function boostedQueue(address account, address validator) external view returns (uint32 blockNumberLast, uint128 balance);
}