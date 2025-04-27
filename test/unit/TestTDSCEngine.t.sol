// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployTDSCEngine} from "script/DeployTDSCEngine.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {console} from "forge-std/Console.sol";
import {ERC20Mock} from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";

contract TestTDSCEngine is Test {
    DeployTDSCEngine deployer;
    TDSCEngine tdscEngine;
    DecentralizedStableCoin tdsc;
    HelperConfig helperConfig;
    address wETHPriceFeed;
    address wBTCPriceFeed;
    address wETH;
    address wBTC;

    address public USER = makeAddr("User");
    uint256 public constant INTIAL_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_ETH_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployTDSCEngine();
        (tdsc, tdscEngine, helperConfig) = deployer.run();
        (wETHPriceFeed, wBTCPriceFeed, wETH, wBTC,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, STARTING_ERC20_ETH_BALANCE);
    }

    /*═══════════════════════════════════════ 
                Test Get USD 
    ═══════════════════════════════════════*/
    function testGetUSDValue() public view {
        uint256 amount = 2e18;
        uint256 expectedAmount = 4000e18;
        uint256 acutalAmount = tdscEngine.getUSDValue(wETH, amount);
        assertEq(expectedAmount, acutalAmount);
    }

    function testRevertIfCollateralIsZero() public {
        vm.prank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INTIAL_COLLATERAL);

        vm.expectRevert(TDSCEngine.TDSCEngine__AmountMustBeGreaterThanZero.selector);
        tdscEngine.depositeCollateral(wETH, 0);
    }
}
