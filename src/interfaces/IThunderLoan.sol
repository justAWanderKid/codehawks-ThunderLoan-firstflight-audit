// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @me the Flash Loan Reciever can Implement this Interface to Repay the Tokens he Borrowed from the Protocol.
interface IThunderLoan {
    
    function repay(address token, uint256 amount) external;

}
