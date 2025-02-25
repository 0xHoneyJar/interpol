pragma solidity ^0.8.23;

import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
contract CUB {
    mapping(address user => uint256 badgesHeld) public badgesHeld;
    uint256 public totalBadges;

    function setBadgesHeld(address user, uint256 amount) external {
        badgesHeld[user] = amount;
    }
    function setTotalBadges(uint256 amount) external {
        totalBadges = amount;
    }
    function badgesPercentageOfUser(
        address _user
    ) public view returns (uint256) {
        uint256 percentage = FPML.fullMulDiv(badgesHeld[_user], 10000, totalBadges);
        // apply ceiling in case of some mistakes
        return percentage > 10000 ? 10000 : percentage;
    }
}
