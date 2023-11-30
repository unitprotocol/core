// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../interfaces/ICurvePool.sol";
import "../../interfaces/curve/ICurvePoolMeta.sol";

/**
 * @title CurveHelper Library
 * @notice Provides functions for interacting with Curve Finance pools. It facilitates the retrieval of coin indices
 *         in Curve pools and meta pools, alongside ensuring minimal gas usage and handling of exceptional scenarios.
 * @dev Assumes compliance with standard Curve pool interface. Functions are view-only but may revert on errors.
 */
library CurveHelper {

    /// @notice The maximum number of coins supported by the Curve pool
    int128 public constant MAX_COINS = 30;

    /**
     * @notice Gets the index of a coin in a Curve meta pool
     * @param _pool The Curve meta pool
     * @param _coin The address of the coin
     * @return The index of the coin in the meta pool
     * @dev Iterates through coins in the meta pool and its base pool to find the index
     * @dev Throws if the pool is broken or the coin is not found
     */
    function getCoinIndexInMetaPool(ICurvePoolMeta _pool, address _coin) internal view returns (int128) {
        int128 basePoolIndex = 0;
        for (int128 i=0; i < MAX_COINS; i++) {
            address coin = tryGetCoin(_pool, i);
            if (coin == address(0)) {
                basePoolIndex = i - 1;
                break;
            } else if (_coin == coin) {
                return i;
            }
        }
        require(basePoolIndex > 0, "Unit Protocol Swappers: BROKEN_POOL"); // expected that base pool is the last

        int128 coinIndexInBasePool = getCoinIndexInPool(ICurvePool(_pool.base_pool()), _coin);
        require(coinIndexInBasePool >= 0, "Unit Protocol Swappers: BROKEN_POOL");

        int128 coinIndex = coinIndexInBasePool + basePoolIndex;
        require(coinIndex >= coinIndexInBasePool, "Unit Protocol Swappers: BROKEN_POOL"); // assert from safe math since here we use int128

        return coinIndex;
    }

    /**
     * @notice Gets the index of a coin in a Curve pool
     * @param _pool The Curve pool
     * @param _coin The address of the coin
     * @return The index of the coin in the pool
     * @dev Iterates through coins in the pool to find the index
     * @dev Reverts if the coin is not found in the pool
     */
    function getCoinIndexInPool(ICurvePool _pool, address _coin) internal view returns (int128) {
        for (int128 i=0; i < MAX_COINS; i++) {
            address coin = tryGetCoin(_pool, i);
            if (coin == address(0)) {
                break;
            } else if (_coin == coin) {
                return i;
            }
        }

        revert("Unit Protocol Swappers: COIN_NOT_FOUND_IN_POOL");
    }

    /**
     * @notice Tries to get the address of a coin in a pool at a specific index
     * @param _pool The Curve pool
     * @param i The index of the coin
     * @return The address of the coin at the given index or address(0) if not successful
     * @dev Uses a low-level staticcall with limited gas to fetch the coin address
     */
    function tryGetCoin(ICurvePool _pool, int128 i) private view returns (address) {
        (bool success,  bytes memory data) = address(_pool).staticcall{gas:20000}(abi.encodeWithSignature("coins(uint256)", uint(i)));
        if (!success || data.length != 32) {
            return address(0);
        }

        return bytesToAddress(data);
    }

    /**
     * @notice Converts bytes to an address
     * @param _bytes The bytes to convert
     * @return addr The converted address
     * @dev Assumes that the input bytes are at least 32 bytes long
     */
    function bytesToAddress(bytes memory _bytes) private pure returns (address addr) {
        assembly {
          addr := mload(add(_bytes, 32))
        }
    }
}