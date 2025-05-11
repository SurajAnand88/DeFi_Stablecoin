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
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

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
    address public LIQUIDATION_USER = makeAddr("liquidationUser");
    uint256 public constant INITIAL_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_ETH_BALANCE = 100 ether;
    uint256 public constant USD_AMOUNT_IN_WEI = 1000e18; //or 1000 ether;
    uint256 public constant INITTIAL_DEPOSITE_COLLATERAL = 1 ether; // or 5e17
    uint256 public constant INITTIAL_DEPOSITE_COLLATERAL_LIQUIDATION_USER = 10 ether; // or 5e17
    uint256 public constant INITIAL_TDSC_MINT_LIQUIDATION_USER = 4500e18; // or 5e17
    uint256 public constant REDEEM_COLLATERAL = 0.5 ether; // or 5e17
    uint256 public constant INITIAL_TDSC_MINT = 999e18;
    uint256 public constant TDSC_TO_BURN = 500e18;
    uint256 public constant BURN_TDSC_ABOVE_HEALTHFACTOR = 100;
    uint256 public constant MINTING_TDSC_ABOVE_HEALTHFACTOR = 1001e18;
    uint256 public constant EXPECTED_BROKEN_HEALTHFACTOR = 0;
    int256 public constant UPDATED_ETHUSD_PRICEFEED = 1500 * 1e8;
    uint256 public constant DEBT_TDSC_TO_COVER = 554e18;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    function setUp() public {
        deployer = new DeployTDSCEngine();
        (tdsc, tdscEngine, helperConfig) = deployer.run();
        (wETHPriceFeed, wBTCPriceFeed, wETH, wBTC,) = helperConfig.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, STARTING_ERC20_ETH_BALANCE);
        ERC20Mock(wETH).mint(LIQUIDATION_USER, STARTING_ERC20_ETH_BALANCE);
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
        (uint256 totalTDSCMinted, uint256 collaterAmountInUSD) = tdscEngine.getUserAccountInformation(USER);
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
            abi.encodeWithSelector(
                TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR, USER
            )
        );
        tdscEngine.mintTDSC(MINTING_TDSC_ABOVE_HEALTHFACTOR);
    }

    function testMintTDSC() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        (uint256 totalTDSCMinted,) = tdscEngine.getUserAccountInformation(USER);
        assertEq(totalTDSCMinted, INITIAL_TDSC_MINT);
        vm.stopPrank();
    }

    function testcollateralDepositeAndMintTDSC() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.collateralDepositeAndMintTDSC(wETH, INITTIAL_DEPOSITE_COLLATERAL, INITIAL_TDSC_MINT);
        (uint256 totalTDSCMinted, uint256 totalCollateralAmountInUSD) = tdscEngine.getUserAccountInformation(USER);
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
        uint256 userPrevTDSCBalance = tdscEngine.getUserTDSCBalance();
        tdscEngine.burnTDSC(TDSC_TO_BURN);
        uint256 userPrevCollateralBalance = tdscEngine.getUserCollateralBalance(wETH);
        uint256 prevBalanceOfDSCEngine = IERC20(wETH).balanceOf(address(tdscEngine));
        tdscEngine.redeemCollateral(wETH, REDEEM_COLLATERAL);
        uint256 userBalanceAfterRedeem = tdscEngine.getUserCollateralBalance(wETH);
        uint256 userTDSCBalanceAfterRedeem = tdscEngine.getUserTDSCBalance();
        uint256 afterBalanceOfDSCEngine = IERC20(wETH).balanceOf(address(tdscEngine));
        assertEq(userBalanceAfterRedeem, (userPrevCollateralBalance - REDEEM_COLLATERAL));
        assertEq(prevBalanceOfDSCEngine, (afterBalanceOfDSCEngine + REDEEM_COLLATERAL));
        assertEq(userPrevTDSCBalance, (TDSC_TO_BURN + userTDSCBalanceAfterRedeem));
        vm.stopPrank();
    }

    function testReedemCollateralRevertIfTDSCNotBurned() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        vm.expectRevert(
            abi.encodeWithSelector(
                TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR, USER
            )
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
            abi.encodeWithSelector(
                TDSCEngine.TDSCEngine__BreaksHealthFactor.selector, EXPECTED_BROKEN_HEALTHFACTOR, USER
            )
        );
        tdscEngine.redeemCollateralForTDSC(wETH, REDEEM_COLLATERAL, BURN_TDSC_ABOVE_HEALTHFACTOR);
        vm.stopPrank();
    }

    /*═══════════════════════════════════════ 
                Test Burn 
    ═══════════════════════════════════════*/

    function testBurnTDSC() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        (uint256 totalTDSCBeforeBurn,) = tdscEngine.getUserAccountInformation(USER);
        IERC20(tdsc).approve(address(tdscEngine), TDSC_TO_BURN);
        tdscEngine.burnTDSC(TDSC_TO_BURN);
        (uint256 totalTDSCAfterBurn,) = tdscEngine.getUserAccountInformation(USER);
        assertEq(totalTDSCBeforeBurn, (totalTDSCAfterBurn + TDSC_TO_BURN));
        vm.stopPrank();
    }

    function testUserAbleToRedeemAllCollateral() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateral(wETH, INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.mintTDSC(INITIAL_TDSC_MINT);

        (uint256 totalTDSCMinted, uint256 totalCollateralAmountInUSD) = tdscEngine.getUserAccountInformation(USER);
        uint256 totalCollateral = tdscEngine.getTokenAmountFromUSD(wETH, totalCollateralAmountInUSD);

        IERC20(tdsc).approve(address(tdscEngine), totalTDSCMinted);
        tdscEngine.burnTDSC(totalTDSCMinted);
        tdscEngine.redeemCollateral(wETH, totalCollateral);

        uint256 userCollateralBalanceAfterRedeem = tdscEngine.getUserCollateralBalance(wETH);
        uint256 userTDSCBalance = tdscEngine.getUserTDSCBalance();
        assertEq(userCollateralBalanceAfterRedeem, 0);
        assertEq(userTDSCBalance, 0);
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
        uint256 btcDepositedBalance = tdscEngine.getUSDValue(wBTC, INITTIAL_DEPOSITE_COLLATERAL);
        uint256 ethDepostedBalance = tdscEngine.getUSDValue(wETH, INITTIAL_DEPOSITE_COLLATERAL);
        console.log(btcDepositedBalance, ethDepostedBalance);

        uint256 totalUserBalanceInUsd = tdscEngine.getUserCollaterAmountInUSD(USER);
        assertEq(totalUserBalanceInUsd, (btcDepositedBalance + ethDepostedBalance));
    }

    /*═══════════════════════════════════════ 
                test liquidation 
    ═══════════════════════════════════════*/

    function testLiquidation() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        (uint256 userPretdsc,) = tdscEngine.getUserAccountInformation(USER);
        MockV3Aggregator(wETHPriceFeed).updateAnswer(UPDATED_ETHUSD_PRICEFEED);
        IERC20(tdsc).approve(address(tdscEngine), DEBT_TDSC_TO_COVER);
        vm.stopPrank();
        vm.startPrank(LIQUIDATION_USER);
        IERC20(tdsc).approve(address(tdscEngine), DEBT_TDSC_TO_COVER);
        tdscEngine.liquidate(wETH, USER, DEBT_TDSC_TO_COVER);
        vm.stopPrank();
        (uint256 totalTdsc, uint256 userCollaterBalInUSD) = tdscEngine.getUserAccountInformation(USER);
        uint256 userCollaterAfterLiqudation = tdscEngine.getTokenAmountFromUSD(wETH, userCollaterBalInUSD);
        vm.prank(USER);
        uint256 userEthBal = tdscEngine.getUserCollateralBalance(wETH);
        assertEq(userCollaterAfterLiqudation, userEthBal);
        assertEq(totalTdsc, (userPretdsc - DEBT_TDSC_TO_COVER));
    }

    function testLiquidationRevertsIfUsersHealthFactorIsOK() public depositeCollateral mintTDSC(INITIAL_TDSC_MINT) {
        vm.stopPrank();
        vm.startPrank(LIQUIDATION_USER);
        IERC20(tdsc).approve(address(tdscEngine), DEBT_TDSC_TO_COVER);
        vm.expectRevert(TDSCEngine.TDSCEngine__HealthFactorIsOK.selector);
        tdscEngine.liquidate(wETH, USER, DEBT_TDSC_TO_COVER);
        vm.stopPrank();
    }
    /*═══════════════════════════════════════ 
                Modifiers
    ═══════════════════════════════════════*/

    modifier depositeCollateral() {
        depositeCollateraltoLiquidationUser();
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL);
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(USER, wETH, INITTIAL_DEPOSITE_COLLATERAL);
        tdscEngine.depositeCollateral(wETH, INITTIAL_DEPOSITE_COLLATERAL);
        _;
    }

    function depositeCollateraltoLiquidationUser() public {
        vm.startPrank(LIQUIDATION_USER);
        ERC20Mock(wETH).approve(address(tdscEngine), INITTIAL_DEPOSITE_COLLATERAL_LIQUIDATION_USER);
        tdscEngine.depositeCollateral(wETH, INITTIAL_DEPOSITE_COLLATERAL_LIQUIDATION_USER);
        tdscEngine.mintTDSC(INITIAL_TDSC_MINT_LIQUIDATION_USER);
        vm.stopPrank();
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
