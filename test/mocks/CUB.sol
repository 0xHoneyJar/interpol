pragma solidity ^0.8.23;


contract CUB {
    mapping(address user => uint256 badgesHeld) public badgesHeld;

    function setBadgesHeld(address user, uint256 amount) external {
        badgesHeld[user] = amount;
    }
}
