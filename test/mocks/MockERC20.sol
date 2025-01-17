pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    bool internal use18Decimals = true;

    function name() public view override returns (string memory) {
        return "MockERC20";
    }

    function symbol() public view override returns (string memory) {
        return "MCK";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return use18Decimals ? 18 : 6;
    }

    function setUse18Decimals(bool _use18Decimals) external {
        use18Decimals = _use18Decimals;
    }


}
