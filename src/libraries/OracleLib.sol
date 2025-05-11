// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from
    "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Suraj
 * @notice This library is used to check the Chainlink Oracle for Stale data.
 *
 * If a price is stale, the function will revert and render the TDSCEngine unusable - this is by design
 * We want TDSCEngine to freeze if the prices becomes stale.
 *
 * So if the chainlink network goes down and you have too much money locked in the protocol.... that's too bad.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant MAX_TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;

        if (secondsSince > MAX_TIMEOUT) revert OracleLib__StalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
