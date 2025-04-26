// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";

contract DeployDecentralizedStablecoin is Script {
    function run() public returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        DecentralizedStableCoin decentralizedStablecoin = new DecentralizedStableCoin();
        vm.stopBroadcast();
        return decentralizedStablecoin;
    }
}
