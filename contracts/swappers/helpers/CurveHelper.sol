// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../interfaces/ICurvePool.sol";
import "../../interfaces/curve/ICurvePoolMeta.sol";

library CurveHelper {

    int128 public constant MAX_COINS = 30;

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

    function tryGetCoin(ICurvePool _pool, int128 i) private view returns (address) {
        (bool success,  bytes memory data) = address(_pool).staticcall{gas:20000}(abi.encodeWithSignature("coins(uint256)", uint(i)));
        if (!success || data.length != 32) {
            return address(0);
        }

        return bytesToAddress(data);
    }

    function bytesToAddress(bytes memory _bytes) private pure returns (address addr) {
        assembly {
          addr := mload(add(_bytes, 32))
        }
    }
}
