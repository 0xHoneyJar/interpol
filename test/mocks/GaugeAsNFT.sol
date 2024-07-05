// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC721} from "solady/tokens/ERC721.sol";

/*
    Follow same ABI as BGT Station gauges.
    Mints a NFT to represent the position of the user.
*/
contract GaugeAsNFT is ERC721 {
    event Staked(address indexed staker, uint256 amount);

    address public token;
    mapping(uint256 id => uint256 amount) public idToAmountStaked;
    uint256 count;

    constructor(address _token) {
        token = _token;
    }

    function name() public view override returns (string memory) {
        return "GaugeAsNFT";
    }

    function symbol() public view override returns (string memory) {
        return "GaugeAsNFT";
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return "";
    }

    function stake(uint256 amount) external {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 tokenId = count++;
        _mint(msg.sender, tokenId);
        idToAmountStaked[tokenId] = amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 tokenId) external {
        // prettier-ignore
        require(ownerOf(tokenId) == msg.sender, "GaugeAsNFT: caller is not owner");
        uint256 amount = idToAmountStaked[tokenId];
        _burn(tokenId);
        ERC20(token).transfer(msg.sender, amount);
    }

    function getReward(address account) external {}
    function exit() external {}
}
