// SPDX-License-Identifier: MIT

//Layout of the contract
// version
// imports
// interfaces, libraried , contracts
// errors
//State Variables
// Events
// Modifiers
// Functions

// Layout of the Functions
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view and pure functions

/**
 * @title Dencentralized Stable Coin
 * @author Suraj
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a
 * 1 token == 1$ peg.
 *
 * Collateral : Exogenous
 * Minting : Algorithmic
 * Relative Stability : Pegged to USD
 *
 *
 * It is similar to DAI if DAI had no governance , no fees, and was only backed by wETH and wBTC.
 *
 * Our TDSC system should always be "overcollaterized". At no point , should the value of all
 * collateral <= the $ backed value of all the TDSC.
 *
 *
 * @notice This contract is the core of the TDSC system . It handles all the logic for mining
 * and redeeming TDSC, as well as depositing and withdrawing collateral
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) System.
 *
 */
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "../lib/openzepplin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzepplin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/Console.sol";

contract TDSCEngine is ReentrancyGuard {
    /*═══════════════════════════════════════
                Errors
    ═══════════════════════════════════════*/

    error TDSCEngine__AmountMustBeGreaterThanZero();
    error TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual();
    error TDSCEngine__TokenNotAllowed();
    error TDSCEngine_CollateralTransferFailed();
    error TDSCEngine__BreaksHealthFactor(uint256 healthFactor,address user);
    error TDSCEngine__MintFailed();
    error TDSCEngine__TransferFailed();
    error TDSCEngine__HealthFactorIsOK();
    error TDSCEngine__UserHealthFactorNotImproved();
    /*═══════════════════════════════════════
                State Variables
    ═══════════════════════════════════════*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means 10% bonus

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 collateral)) private s_usersCollateralDeposit;
    mapping(address user => uint256 tdsc) private s_UsersTDSCBalance;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_Tdsc;

    /*═══════════════════════════════════════
                Events
    ═══════════════════════════════════════*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, uint256 amount, address indexed token);
    /*═══════════════════════════════════════
                Modifiers
    ═══════════════════════════════════════*/

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert TDSCEngine__AmountMustBeGreaterThanZero();
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert TDSCEngine__TokenNotAllowed();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address TDSCAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_Tdsc = DecentralizedStableCoin(TDSCAddress);
    }

    /*═══════════════════════════════════════ 
                Functions
    ═══════════════════════════════════════*/

    /*═══════════════════════════════════════ 
                External Functions
    ═══════════════════════════════════════*/

    /**
     *
     * @param tokenCollateralAddress : The address of the token to deposit as Collateral
     * @param amountCollateral : The amount of the collateral to deposit
     * @param amountTDSCtoMint : The amount of the TDSC to mint
     * @notice This funciton will deposit the collateral and mint TDSC in one transaction
     */
    function depositeCollateralAndMintTDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountTDSCtoMint
    ) external {
        depositeCollateral(tokenCollateralAddress, amountCollateral);
        mintTDSC(amountTDSCtoMint);
    }

    /*
     *  @notice follow the CEI pattern 
     *  @param tokenCollateralAddress the address of the token to deposite as collateral
     * @param amountCollateral the amount of collateral to deposite
     */

    function depositeCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_usersCollateralDeposit[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert TDSCEngine_CollateralTransferFailed();
    }

    /**
     *
     * @param tokenCollateralAddress : The collateral token address to redeem
     * @param amountCollateral : The amount of collateral token to redeem
     * @param amountTDSC : The amount of TDSC to burn
     * This function burns TDSC and redeem collateral in a single function call
     */
    function redeemCollateralForTDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountTDSC)
        external
    {
        burnTDSC(amountTDSC);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /**
     *
     * @param tokenCollateralAddress : The collateral token address to redeem
     * @param amountCollateral : the amount of collateral token to redeem
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender); // from = should be address(this);
        _revertIfHealthFactorBroken(msg.sender);
    }

    /*
     *  @notice follow the CEI pattern 
     *  @param amountTDSCtoMint the amount of decentralized stablecoin to mint 
     * @param user must have more collateral value than minimun threshold
     */

    function mintTDSC(uint256 amountTDSCtoMint) public moreThanZero(amountTDSCtoMint) nonReentrant {
        s_UsersTDSCBalance[msg.sender] += amountTDSCtoMint;
        _revertIfHealthFactorBroken(msg.sender);
        bool mintSuccess = i_Tdsc.mint(msg.sender, amountTDSCtoMint);
        if (!mintSuccess) revert TDSCEngine__MintFailed();
    }

    // function withdrawCollateralForTDSC() external {}

    /**
     *
     * @param amountTDSC : The amount of TDSC to burn
     */
    function burnTDSC(uint256 amountTDSC) public moreThanZero(amountTDSC) nonReentrant {
        _burnTDSC(amountTDSC, msg.sender, msg.sender);
        _revertIfHealthFactorBroken(msg.sender);
    }

    /**
     *
     * @param collateral : The ERC20 collateral address to liquidate from the user
     * @param user : The user who has broken the health factor. Their health factor should be
     * below MIN_HEALTH_FACTOR
     * @param debtToCover :The amount of TDSC you want to burn to improve the user's health factor
     * @notice You can partially liquidate user
     * @notice You will get liquidation bonus for taking the users funds
     * @notice This function working assumes that the protocol is rougly 200% over collateralized
     * in order for this to work
     * @notice A known bug would be if the protocol were 100% or less collateralized ,
     * the we wouldn't be able to incentive the liquidators.
     * For example , if the price of the collateral plummed before anyone could be liquidated
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // need to check the health factor
        uint256 startingHealthFactor = _healthFactor(user);
        console.log("Starting HealthFactor",startingHealthFactor);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) revert TDSCEngine__HealthFactorIsOK();
        uint256 collateralAmount = getTokenAmountFromUSD(collateral, debtToCover);
        // We are giving the liquidator a 10% bonus
        //We should impliment a feature to liquidate in the event protocol is insolvent
        // s_usersCollateralDeposit[msg.sender][collateral] -= collateralAmount;
        uint256 collateralBonus = (collateralAmount * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollaterlaToRedeem = collateralAmount + collateralBonus;
        _burnTDSC(debtToCover, user, msg.sender);
        _redeemCollateral(collateral, totalCollaterlaToRedeem, user, msg.sender);
        // Need to burn TDSC now


        uint256 endingUserHealthFactor = _healthFactor(user);
        console.log("Ending HealthFactor",endingUserHealthFactor);
        if (endingUserHealthFactor <= startingHealthFactor) {
            revert TDSCEngine__UserHealthFactorNotImproved();
        }
        _revertIfHealthFactorBroken(msg.sender);
    }

    /*═══════════════════════════════════════ 
        Private and Internal Functions
    ═══════════════════════════════════════*/

    /**
     *
     * @param amountToBurnTDSC: the amount of TDSC to burn
     * @param onBehalfOf : The address on behalf of burning the tdsc
     * @param tdscFrom : who's paying the debt
     * @dev Low-level internal function , do not call it unless function calling it checking for healthfactor being broken
     */
    function _burnTDSC(uint256 amountToBurnTDSC, address onBehalfOf, address tdscFrom) private {
        s_UsersTDSCBalance[onBehalfOf] -= amountToBurnTDSC;
        (bool success) = i_Tdsc.transferFrom(tdscFrom, address(this), amountToBurnTDSC);
        if (!success) revert TDSCEngine__TransferFailed();
        i_Tdsc.burn(amountToBurnTDSC);
    }   

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        console.log("Amount",amountCollateral);
        s_usersCollateralDeposit[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(address(this), to, amountCollateral, tokenCollateralAddress);
        (bool success) = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) revert TDSCEngine__TransferFailed();
        _revertIfHealthFactorBroken(msg.sender);
    }

    /**
     *
     * @return totalTDSCMinted by user
     * @return collaterAmountInUSD deposited by user
     */

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalTDSCMinted, uint256 collaterAmountInUSD)
    {
        totalTDSCMinted = s_UsersTDSCBalance[user];
        collaterAmountInUSD = getUserCollaterAmountInUSD(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If the user is below 1, they can get liquidated
     * Check the ratio  of collateral to TDSC minted to get the health factor
     */

    function _healthFactor(address user) private view returns (uint256) {
        // Get Total TDSC minted
        // Get total Collaterla depostied in USD
        if (s_UsersTDSCBalance[user] == 0) return type(uint256).max;
        (uint256 totalTDSCMinted, uint256 totalCollaterlaValueInUSD) = _getAccountInformation(user);
        uint256 totalAdjustedCollateral = (totalCollaterlaValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (totalAdjustedCollateral * PRECISION) / totalTDSCMinted / PRECISION;
    }
    
    

    function _revertIfHealthFactorBroken(address user) internal view {
        // Check health factor (Do user have enough collateral)
        // Revert if thery don't
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) revert TDSCEngine__BreaksHealthFactor(healthFactor,msg.sender);
    }



    /*═══════════════════════════════════════ 
        Public and External view Functions
    ═══════════════════════════════════════*/

    function getTokenAmountFromUSD(address token, uint256 debtUSDAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((debtUSDAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }


    /**
     *
     * @return totalCollaterlAmountInUSD deposited by user
     */
    function getUserCollaterAmountInUSD(address user) public view returns (uint256 totalCollaterlAmountInUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_usersCollateralDeposit[user][token];
            totalCollaterlAmountInUSD += getUSDValue(token, amount);
        }
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        //get the price feed
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION);
    }

    function getUserCollateralBalance(address tokenCollateralAddress) external view returns (uint256) {
        return s_usersCollateralDeposit[msg.sender][tokenCollateralAddress];
    }

    function getUserTDSCBalance() external view returns (uint256) {
        return s_UsersTDSCBalance[msg.sender];
    }

    function getUserAccountInformation(address user) public view returns (uint256 totalTDSCMinted, uint256 collaterAmountInUSD) {
        (totalTDSCMinted, collaterAmountInUSD) = _getAccountInformation(user);
    }
}
