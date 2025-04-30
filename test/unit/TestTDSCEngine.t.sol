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
    uint256 public constant INITIAL_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_ETH_BALANCE = 100 ether;
    uint256 public constant USD_AMOUNT_IN_WEI = 1000e18; //or 1000 ether;
    uint256 public constant INITTIAL_DEPOSITE_COLLATERAL = 0.5 ether; // or 5e17

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    function setUp() public {
        deployer = new DeployTDSCEngine();
        (tdsc, tdscEngine, helperConfig) = deployer.run();
        (wETHPriceFeed, wBTCPriceFeed, wETH, wBTC,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, STARTING_ERC20_ETH_BALANCE);
        
    }

    /*═══════════════════════════════════════ 
                Test Constructor 
    ═══════════════════════════════════════*/

    address[] public token = [wETH];
    address[] public priceFeeds = [wETHPriceFeed, wBTCPriceFeed];

    function testConstructorRevertsIfLengthDoesntMatchPriceFeed() public {
        vm.expectRevert(TDSCEngine.TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual.selector);
        new TDSCEngine(token, priceFeeds, address(tdsc));
    }

     /*═══════════════════════════════════════ 
            Test Deposite Collateral 
    ═══════════════════════════════════════*/

    function testGetTokenAmountFromUSD() public view {
        uint256 expectedAmountToken = 5 * 1e17;
        uint256 tokenAmount = tdscEngine.getTokenAmountFromUSD(wETH, USD_AMOUNT_IN_WEI);
        assertEq(expectedAmountToken, tokenAmount);
    }


    function testRevertIfCollateralIsZero() public {
        vm.prank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITIAL_COLLATERAL);
        vm.expectRevert(TDSCEngine.TDSCEngine__AmountMustBeGreaterThanZero.selector);
        tdscEngine.depositeCollateral(wETH, 0);
    }

    function testDepositeCollateralRevertIfAddressIsNotAllowed() public {
        ERC20Mock tokenTest = new ERC20Mock("TEST","TEST",USER,INITIAL_COLLATERAL);
        vm.expectRevert(TDSCEngine.TDSCEngine__TokenNotAllowed.selector);
        tdscEngine.depositeCollateral(address(tokenTest), INITTIAL_DEPOSITE_COLLATERAL);

    }

    function testCanDepositeCollateral() public depositeCollaterl {
        // uint256 userBalance = tdscEngine.getUserCollateralBalance(wETH);
        // assertEq(userBalance,INITTIAL_DEPOSITE_COLLATERAL);
        (uint256 totalTDSCMinted, uint256 collaterAmountInUSD) = tdscEngine.getUserAccountInformation();
        uint256 expectedCollateralBalance = tdscEngine.getTokenAmountFromUSD(wETH,collaterAmountInUSD);
        assertEq(expectedCollateralBalance,INITTIAL_DEPOSITE_COLLATERAL);
        assertEq(totalTDSCMinted,0);
        vm.stopPrank();
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

    modifier depositeCollaterl{
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(USER,wETH,INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateral(wETH,INITTIAL_DEPOSITE_COLLATERAL);
        _;
    }
}
