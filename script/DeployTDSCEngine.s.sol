// SPDX-License-Identifier: MIt
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";

contract DeployTDSCEngine is Script {
    function run() external returns (DecentralizedStableCoin, TDSCEngine) {
        vm.startBroadcast();
        DecentralizedStableCoin tdsc = new DecentralizedStableCoin();
        TDSCEngine tdscEngine = new TDSCEngine();
        vm.stopBroadcast();
    }
}
