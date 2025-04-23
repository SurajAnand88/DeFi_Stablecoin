// SPDX-License-Identifier: MIT

//Layout of the contract
// version
// imports
// interfaces, libraried , contracts
// errors
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
pragma solidity 0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";

contract TDSCEngine {
    /*═══════════════════════════════════════
                Errors
═══════════════════════════════════════*/

    error TDSCEngine__AmountMustBeGreaterThanZero();
    error TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual();

    /*═══════════════════════════════════════
                State Variables
═══════════════════════════════════════*/

    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_Tdsc;

    /*═══════════════════════════════════════
                Modifiers
═══════════════════════════════════════*/

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert TDSCEngine__AmountMustBeGreaterThanZero();
        _;
    }

    // modifier isAllowedToken(address tokeAddress) {

    // }

    /*═══════════════════════════════════════ 
                Functions
═══════════════════════════════════════*/

    /*═══════════════════════════════════
    ════ 
                External Functions

═══════════════════════════════════════*/

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address TDSCAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length)
            revert TDSCEngine__TokenAndPriceFeedArrayLengthMustBeEqual();

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_Tdsc = DecentralizedStableCoin(TDSCAddress);
    }

    function depositeCollateralAndMintTDSC() external {}

    /*

     *  @param tokenCollateralAddress the
      address of the token to deposite as collateral
     * @param amountCollateral the amount
     *  of collateral to deposite
     */

    function depositeCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) {}

    function redeemCollateralForTDSC() external {}

    function redeemCollateral() external {}

    function mintTDSC() external {}

    function withdrawCollateralForTDSC() external {}

    function burnTDSC() external {}

    function liquidate() external {}
}
