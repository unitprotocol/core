// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title IAggregator
 * @dev Interface for Chainlink or similar oracle aggregators to fetch price feed information.
 */
interface IAggregator {
    
    /**
     * @notice Retrieves the latest available answer from the oracle.
     * @return The latest answer.
     */
    function latestAnswer() external view returns (int256);
    
    /**
     * @notice Retrieves the timestamp of the latest update.
     * @return Timestamp of the last update.
     */
    function latestTimestamp() external view returns (uint256);
    
    /**
     * @notice Retrieves the identifier of the latest round.
     * @return The latest round ID.
     */
    function latestRound() external view returns (uint256);
    
    /**
     * @notice Fetches the historical answer for a specific round.
     * @param roundId The round ID to retrieve the answer for.
     * @return The answer of the specified round.
     */
    function getAnswer(uint256 roundId) external view returns (int256);
    
    /**
     * @notice Fetches the timestamp when a specific round was updated.
     * @param roundId The round ID to retrieve the timestamp for.
     * @return The timestamp of the specified round.
     */
    function getTimestamp(uint256 roundId) external view returns (uint256);
    
    /**
     * @notice Retrieves the number of decimals used by the oracle.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint256);
    
    /**
     * @notice Provides the round data including the answer and timestamps for the latest round.
     * @return roundId The round ID of the latest round.
     * @return answer The answer provided by the latest round.
     * @return startedAt The timestamp at which the latest round started.
     * @return updatedAt The timestamp at which the latest round was updated.
     * @return answeredInRound The round ID in which the returned answer was computed.
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
    );

    /**
     * @dev Emitted when a new answer is provided by the oracle.
     * @param current The value of the latest answer.
     * @param roundId The round ID when the answer was updated.
     * @param timestamp The timestamp when the answer was updated.
     */
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
    
    /**
     * @dev Emitted when a new round is started.
     * @param roundId The round ID that was started.
     * @param startedBy The address that started the round.
     * @param startedAt The timestamp at which the round was started.
     */
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}