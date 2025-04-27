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

contract TDSCEngine is ReentrancyGuard {
    /*═══════════════════════════════════════
                Errors
    ═══════════════════════════════════════*/

    error TDSCEngine__AmountMustBeGreaterThanZero();
    error TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual();
    error TDSCEngine__TokenNotAllowed();
    error TDSCEngine_CollateralTransferFailed();
    error TDSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error TDSCEngine__MintFailed();
    /*═══════════════════════════════════════
                State Variables
    ═══════════════════════════════════════*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 collateral)) private s_usersCollateralDeposit;
    mapping(address user => uint256 tdsc) private s_UsersTDSCBalance;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_Tdsc;

    /*═══════════════════════════════════════
                Events
    ═══════════════════════════════════════*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
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

    /*═══════════════════════════════════════ 
                Functions
    ═══════════════════════════════════════*/

    /*═══════════════════════════════════════ 
                External Functions
    ═══════════════════════════════════════*/

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

    function redeemCollateralForTDSC() external {}

    function redeemCollateral() external {}

    /*
     *  @notice follow the CEI pattern 
     *  @param amountTDSCtoMint the amount of decentralized stablecoin to mint 
     * @param user must have more collateral value than minimun threshold
     */

    function mintTDSC(uint256 amountTDSCtoMint) public moreThanZero(amountTDSCtoMint) nonReentrant {
        s_UsersTDSCBalance[msg.sender] += amountTDSCtoMint;
        _revertHealthFactor(msg.sender);

        bool mintSuccess = i_Tdsc.mint(msg.sender, amountTDSCtoMint);
        if (!mintSuccess) revert TDSCEngine__MintFailed();
    }

    function withdrawCollateralForTDSC() external {}

    function burnTDSC() external {}

    function liquidate() external {}

    /*═══════════════════════════════════════ 
        Private and Internal Functions
    ═══════════════════════════════════════*/
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
        (uint256 totalTDSCMinted, uint256 totalCollaterlaValueInUSD) = _getAccountInformation(user);
        uint256 totalAdjustedCollateral = (totalCollaterlaValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return ((totalAdjustedCollateral / PRECISION) / totalTDSCMinted);
    }

    function _revertHealthFactor(address user) internal view {
        // Check health factor (Do user have enough collateral)
        // Revert if thery don't
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) revert TDSCEngine__BreaksHealthFactor(healthFactor);
    }

    /*═══════════════════════════════════════ 
        Public and External view Functions
    ═══════════════════════════════════════*/

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
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
