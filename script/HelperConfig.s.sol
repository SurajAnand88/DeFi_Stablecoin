// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/Console.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wETHpriceFeed;
        address wBTCpriceFeed;
        address wETH;
        address wBTC;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 private constant DECIMAL = 8;
    int256 private constant ETH_USD_PRICE = 2000 * 1e8;
    int256 private constant BTC_USD_PRICE = 20000 * 1e8;
    uint256 private constant INITIAL_BALANCE = 100e8;
    uint256 private constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETHpriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCpriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wETH: 0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323,
            wBTC: 0x5928A372De475721231B4411a26a01602E0a6dFa,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETHpriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUSDPriceFeed = new MockV3Aggregator(DECIMAL, ETH_USD_PRICE);
        ERC20Mock wEthMock = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_BALANCE);

        MockV3Aggregator btcUSDPriceFeed = new MockV3Aggregator(DECIMAL, BTC_USD_PRICE);
        ERC20Mock wBtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_BALANCE);

        vm.stopBroadcast();

        return NetworkConfig({
            wETHpriceFeed: address(ethUSDPriceFeed),
            wBTCpriceFeed: address(btcUSDPriceFeed),
            wETH: address(wEthMock),
            wBTC: address(wBtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
