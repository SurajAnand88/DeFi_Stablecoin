// SPDX-License-Identifier: MIT
// What are our Invariants - What are the properties of our system that should always hold

// 1. That total supply of the TDSC should be less than the total value of the collateral
// 2. Getter view functions should never revert <= evergreen invariants

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {DeployTDSCEngine} from "script/DeployTDSCEngine.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "../../lib/openzepplin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DecentralizedStableCoin tdsc;
    TDSCEngine tdscEngine;
    HelperConfig helperConfig;
    Handler handler;
    address wETHpriceFeed;
    address wBTCpriceFeed;
    address wETH;
    address wBTC;
    address public LIQUIDATION_USER = makeAddr("liquidationUser");
    uint256 public constant INITTIAL_DEPOSITE_COLLATERAL_LIQUIDATION_USER = 10 ether; // or 5e17
    uint256 public constant INITIAL_TDSC_MINT_LIQUIDATION_USER = 10000e18; // or 5e17
    uint256 public constant STARTING_ERC20_ETH_BALANCE = 100 ether;

    function setUp() external {
        DeployTDSCEngine deployer = new DeployTDSCEngine();
        (tdsc, tdscEngine, helperConfig) = deployer.run();
        (wETHpriceFeed, wBTCpriceFeed, wETH, wBTC,) = helperConfig.activeNetworkConfig();
        // targetContract(address(tdscEngine));
        //Don't call redeemcollateral unless there is some collateral to redeem
        handler = new Handler(tdsc, tdscEngine);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalTDSCSupply() public view {
        //get the value of all the collateral in our protocol
        // get the total value of debt (TDSC)
        uint256 engineEthBalance = ERC20Mock(wETH).balanceOf(address(tdscEngine));
        uint256 engineBtcBalance = ERC20Mock(wBTC).balanceOf(address(tdscEngine));

        uint256 engineEthUSDBalance = tdscEngine.getUSDValue(wETH, engineEthBalance);
        uint256 engineBtcUSDBalance = tdscEngine.getUSDValue(wBTC, engineBtcBalance);

        uint256 totalTDSCMinted = tdsc.totalSupply();
        assert((engineBtcUSDBalance + engineEthUSDBalance) >= totalTDSCMinted);
    }
}
