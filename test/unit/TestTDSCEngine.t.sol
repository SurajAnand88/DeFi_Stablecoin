// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployTDSCEngine} from "script/DeployTDSCEngine.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {console} from "forge-std/Console.sol";
import {ERC20Mock} from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "../../lib/openzepplin-contracts/contracts/token/ERC20/IERC20.sol";

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
    uint256 public constant INITTIAL_DEPOSITE_COLLATERAL = 1 ether; // or 5e17
    uint256 public constant REDEEM_COLLATERAL = 0.5 ether; // or 5e17
    uint256 public constant INITIAL_TDSC_MINT = 999;
    uint256 public constant TDSC_TO_BURN = 500;
    uint256 public constant BURN_TDSC_ABOVE_HEALTHFACTOR = 100;
    uint256 public constant MINTING_TDSC_ABOVE_HEALTHFACTOR = 1001;
    uint256 public constant EXPECTED_BROKEN_HEALTHFACTOR = 0;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    function setUp() public {
        deployer = new DeployTDSCEngine();
        (tdsc, tdscEngine, helperConfig) = deployer.run();
        (wETHPriceFeed, wBTCPriceFeed, wETH, wBTC,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, STARTING_ERC20_ETH_BALANCE);
        ERC20Mock(wBTC).mint(USER, STARTING_ERC20_ETH_BALANCE);
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
        ERC20Mock tokenTest = new ERC20Mock("TEST", "TEST", USER, INITIAL_COLLATERAL);
        vm.expectRevert(TDSCEngine.TDSCEngine__TokenNotAllowed.selector);
        tdscEngine.depositeCollateral(address(tokenTest), INITTIAL_DEPOSITE_COLLATERAL);
    }

    function testCanDepositeCollateral() public depositeCollateral {
        // uint256 userBalance = tdscEngine.getUserCollateralBalance(wETH);
        // assertEq(userBalance,INITTIAL_DEPOSITE_COLLATERAL);
        (uint256 totalTDSCMinted, uint256 collaterAmountInUSD) = tdscEngine.getUserAccountInformation();
        uint256 expectedCollateralBalance = tdscEngine.getTokenAmountFromUSD(wETH, collaterAmountInUSD);
        assertEq(expectedCollateralBalance, INITTIAL_DEPOSITE_COLLATERAL);
        assertEq(totalTDSCMinted, 0);
        vm.stopPrank();
    }
    /*═══════════════════════════════════════ 
                Test Mint
    ═══════════════════════════════════════*/

    function testMintTDSCRevertIfHealthFactorIsBroken() public depositeCollateral {
        vm.expectRevert(
            abi.encodeWithSelector(TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR)
        );
        tdscEngine.mintTDSC(MINTING_TDSC_ABOVE_HEALTHFACTOR);
    }

    function testMintTDSC() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        (uint256 totalTDSCMinted,) = tdscEngine.getUserAccountInformation();
        assertEq(totalTDSCMinted, INITIAL_TDSC_MINT);
        vm.stopPrank();
    }

    function testDepositeCollaterlaAndMintTDSC() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateralAndMintTDSC(wETH, INITTIAL_DEPOSITE_COLLATERAL, INITIAL_TDSC_MINT);
        (uint256 totalTDSCMinted, uint256 totalCollateralAmountInUSD) = tdscEngine.getUserAccountInformation();
        uint256 expectCollateralAmount = tdscEngine.getTokenAmountFromUSD(wETH, totalCollateralAmountInUSD);
        assertEq(expectCollateralAmount, INITTIAL_DEPOSITE_COLLATERAL);
        assertEq(totalTDSCMinted, INITIAL_TDSC_MINT);
        vm.stopPrank();
    }
    /*═══════════════════════════════════════ 
        vvTest Redeem Collateral
    ═══════════════════════════════════════*/

    function testRedeemCollateral() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        //minting the tdsc for collateral;
        IERC20(tdsc).approve(address(tdscEngine), TDSC_TO_BURN);
        //buring the tdsc to redeeming the collateral
        tdscEngine.burnTDSC(TDSC_TO_BURN);
        uint256 userPrevCollateralBalance = tdscEngine.getUserCollateralBalance(wETH);
        uint256 prevBalanceOfDSCEngine = IERC20(wETH).balanceOf(address(tdscEngine));
        tdscEngine.redeemCollateral(wETH, REDEEM_COLLATERAL);
        uint256 userBalanceAfterRedeem = tdscEngine.getUserCollateralBalance(wETH);
        uint256 afterBalanceOfDSCEngine = IERC20(wETH).balanceOf(address(tdscEngine));
        assertEq(userBalanceAfterRedeem, (userPrevCollateralBalance - REDEEM_COLLATERAL));
        assertEq(prevBalanceOfDSCEngine, (afterBalanceOfDSCEngine + REDEEM_COLLATERAL));
        vm.stopPrank();
    }

    function testReedemCollateralRevertIfTDSCNotBurned() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        vm.expectRevert(
            abi.encodeWithSelector(TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR)
        );
        tdscEngine.redeemCollateral(wETH, REDEEM_COLLATERAL);
        vm.stopPrank();
    }

    function testRedeemCollateralForTDSC() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        IERC20(tdsc).approve(address(tdscEngine), TDSC_TO_BURN);
        tdscEngine.redeemCollateralForTDSC(wETH, REDEEM_COLLATERAL, TDSC_TO_BURN);
        vm.stopPrank();
    }

    function testReedemCollaterForTDSCRevertsIfHealthFactorIsBroken()
        public
        depositeCollateral
        mintTDSC(INITIAL_TDSC_MINT)
    {
        IERC20(tdsc).approve(address(tdscEngine), BURN_TDSC_ABOVE_HEALTHFACTOR);
        vm.expectRevert(
            abi.encodeWithSelector(TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR)
        );
        tdscEngine.redeemCollateralForTDSC(wETH, REDEEM_COLLATERAL, BURN_TDSC_ABOVE_HEALTHFACTOR);
        vm.stopPrank();
    }

    /*═══════════════════════════════════════ 
                Test Burn 
    ═══════════════════════════════════════*/

    function testBurnTDSC() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        (uint256 totalTDSCBeforeBurn,) = tdscEngine.getUserAccountInformation();
        IERC20(tdsc).approve(address(tdscEngine), TDSC_TO_BURN);
        tdscEngine.burnTDSC(TDSC_TO_BURN);
        (uint256 totalTDSCAfterBurn,) = tdscEngine.getUserAccountInformation();
        assertEq(totalTDSCBeforeBurn, (totalTDSCAfterBurn + TDSC_TO_BURN));
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

    function testGetUserCollateralBalanceInUSD() public depositeCollateral depositeCollateralBTC {
        uint256 btcDepositedBalance = tdscEngine.getUSDValue(wBTC,INITTIAL_DEPOSITE_COLLATERAL);
        uint256 ethDepostedBalance = tdscEngine.getUSDValue(wETH, INITTIAL_DEPOSITE_COLLATERAL);
        console.log(btcDepositedBalance, ethDepostedBalance);

        uint256 totalUserBalanceInUsd = tdscEngine.getUserCollaterAmountInUSD(USER);
        assertEq(totalUserBalanceInUsd , (btcDepositedBalance+ethDepostedBalance));

    }

    /*═══════════════════════════════════════ 
                Modifiers
    ═══════════════════════════════════════*/
    modifier depositeCollateral() {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(USER, wETH, INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateral(wETH, INITTIAL_DEPOSITE_COLLATERAL);
        _;
    }

    modifier depositeCollateralBTC() {
        vm.startPrank(USER);
        ERC20Mock(wBTC).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateral(wBTC, INITTIAL_DEPOSITE_COLLATERAL);
        _;
    }

    modifier mintTDSC(uint256 amount) {
        tdscEngine.mintTDSC(amount);
        _;
    }
}
