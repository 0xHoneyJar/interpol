// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";

/*
    Follow same ABI as BGT Station gauges.
*/
contract FakeGauge {
    event Staked(address indexed staker, uint256 amount);

    address public token;

    constructor(address _token) {
        token = _token;
    }

    function stake(uint256 amount) external {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        ERC20(token).transfer(msg.sender, amount);
    }

    function getReward(address account) external {}
    function exit() external {}
}
