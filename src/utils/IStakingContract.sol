pragma solidity ^0.8.23;

interface IStakingContract {
    event Staked(address indexed staker, uint256 amount);
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account) external;
    //function balanceOf(address account) external view returns (uint256);
    function exit() external;
}