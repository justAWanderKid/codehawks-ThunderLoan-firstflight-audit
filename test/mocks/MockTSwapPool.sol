// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MockTSwapPool {

    uint256 public priceOfOnePoolTokenInWeth = 1e18;

    function setPrice(uint256 _price) public {
        priceOfOnePoolTokenInWeth = _price;
    }

    function getPriceOfOnePoolTokenInWeth() public view returns (uint256) {
        return priceOfOnePoolTokenInWeth;
    }
}
