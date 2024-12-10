// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVaultAdapter {
    function initialize(
        address locker,
        address vault,
        address stakingToken
    ) external;
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claim() external;
    function stakingToken() external view returns (address);
    function vault() external view returns (address);
}
