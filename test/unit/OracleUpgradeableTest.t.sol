// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest } from "./BaseTest.t.sol";

contract OracleUpgradeableTest is BaseTest {
    function testInitializationOracle() public view {
        assertEq(thunderLoan.getPoolFactoryAddress(), address(mockPoolFactory));
    }

    function testGetPrice() public view {
        assertEq(thunderLoan.getPrice(address(tokenA)), 1e18);
    }
}
