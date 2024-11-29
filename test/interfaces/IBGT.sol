// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IBGT {
    event Redeem(
        address indexed from,
        address indexed receiver,
        uint256 amount
    );
    event QueueBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event CancelBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );
    event ActivateBoost(address indexed sender, address indexed validator);
    event DropBoost(
        address indexed sender,
        address indexed validator,
        uint128 amount
    );

    function minter() external view returns (address);
    function mint(address distributor, uint256 amount) external;
}
