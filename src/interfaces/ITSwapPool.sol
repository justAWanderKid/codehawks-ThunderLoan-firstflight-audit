// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;


// @me Interface to Interact with Tswap Pool
interface ITSwapPool {

    // @me gets Price of a Token In Weth
    // @me it's Used in OracleUpgradeable.sol `getPriceInWeth` funciton.
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);

    function setPrice(uint256 _price) external;

}
