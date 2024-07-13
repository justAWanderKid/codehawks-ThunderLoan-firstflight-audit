// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// @me Interface To Get Pool Of Specific Token From TSwap
interface IPoolFactory {
    
    function getPool(address tokenAddress) external view returns (address);

}
