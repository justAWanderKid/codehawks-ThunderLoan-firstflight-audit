// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { ThunderLoan } from "../src/protocol/ThunderLoan.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployThunderLoan is Script {

    ERC1967Proxy proxy;

    function run() public {
        vm.startBroadcast();
        ThunderLoan thunderLoan = new ThunderLoan();
        proxy = new ERC1967Proxy(address(thunderLoan), "");
        vm.stopBroadcast();
    }
}
