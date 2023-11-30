// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title ChainlinkAggregator_Mock
 * @dev Mock contract for Chainlink Aggregator used for testing purposes.
 */
contract ChainlinkAggregator_Mock {
    // Latest price answer provided by the oracle
    int public latestAnswer;

    // Timestamp of the latest price update
    uint public latestTimestamp = block.timestamp;

    // Number of decimals the answer is in
    uint public decimals;

    // Address of the contract admin
    address admin = msg.sender;

    // Event emitted when the price is updated
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);

    /**
     * @dev Constructor sets the initial price and decimals.
     * @param price Initial price to set.
     * @param _decimals Number of decimals the price is in.
     */
    constructor (int price, uint _decimals) {
        latestAnswer = price;
        decimals = _decimals;
    }

    /**
     * @dev Allows the admin to update the price.
     * @param price New price to be set.
     * @notice Emits the AnswerUpdated event.
     * @throws if the caller is not the admin.
     */
    function setPrice(int price) external {
        require(msg.sender == admin, "Unit Protocol: UNAUTHORIZED");
        latestAnswer = price;
        latestTimestamp = block.timestamp;
        emit AnswerUpdated(int(price), block.timestamp, block.timestamp);
    }

    /**
     * @dev Provides the latest price data.
     * @return roundId The round ID of the latest update (always 0 for mock).
     * @return answer The latest price answer.
     * @return startedAt The timestamp when the round started (always 0 for mock).
     * @return updatedAt The timestamp of the latest price update.
     * @return answeredInRound The round ID when the given answer was provided (always 0 for mock).
     */
    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        answer = latestAnswer;
        updatedAt = latestTimestamp;

        roundId = 0;
        startedAt = 0;
        answeredInRound = 0;
    }
}