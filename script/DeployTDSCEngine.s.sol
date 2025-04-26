// SPDX-License-Identifier: MIt
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployTDSCEngine is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, TDSCEngine) {
        HelperConfig helperConfig = new HelperConfig();
        (address wETHPriceFeed, address wBTCPriceFeed, address wETH, address wBTC, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [wETH, wBTC];
        priceFeedAddresses = [wETHPriceFeed, wBTCPriceFeed];
        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin tdsc = new DecentralizedStableCoin();
        TDSCEngine tdscEngine = new TDSCEngine(tokenAddresses, priceFeedAddresses, address(tdsc));
        vm.stopBroadcast();
        tdsc.transferOwnership(address(tdscEngine));
        return (tdsc, tdscEngine);
    }
}
