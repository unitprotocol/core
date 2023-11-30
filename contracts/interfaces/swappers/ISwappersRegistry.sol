// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./ISwapper.sol";

/**
 * @title ISwappersRegistry
 * @dev Interface for the registry of Swapper contracts.
 */
interface ISwappersRegistry {
    /**
     * @dev Emitted when a new swapper is added to the registry.
     * @param swapper The address of the swapper contract that was added.
     */
    event SwapperAdded(ISwapper swapper);
    
    /**
     * @dev Emitted when a swapper is removed from the registry.
     * @param swapper The address of the swapper contract that was removed.
     */
    event SwapperRemoved(ISwapper swapper);

    /**
     * @dev Returns the identifier of a swapper contract.
     * @param _swapper The address of the swapper contract.
     * @return The identifier of the swapper.
     */
    function getSwapperId(ISwapper _swapper) external view returns (uint);

    /**
     * @dev Returns the swapper contract at a given identifier.
     * @param _id The identifier of the swapper.
     * @return The swapper contract address.
     */
    function getSwapper(uint _id) external view returns (ISwapper);

    /**
     * @dev Checks if a swapper contract is in the registry.
     * @param _swapper The address of the swapper contract.
     * @return True if the swapper is in the registry, false otherwise.
     */
    function hasSwapper(ISwapper _swapper) external view returns (bool);

    /**
     * @dev Returns the number of swapper contracts in the registry.
     * @return The number of swapper contracts.
     */
    function getSwappersLength() external view returns (uint);

    /**
     * @dev Returns an array of all swapper contracts in the registry.
     * @return An array of swapper contract addresses.
     */
    function getSwappers() external view returns (ISwapper[] memory);
}