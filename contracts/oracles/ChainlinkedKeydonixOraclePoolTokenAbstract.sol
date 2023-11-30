// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "./KeydonixOracleAbstract.sol";

/**
 * @title Abstract contract for Chainlinked Keydonix Oracle for Pool Tokens
 * @dev This abstract contract provides an interface for Chainlinked Keydonix Oracle for Pool Tokens.
 */
abstract contract ChainlinkedKeydonixOraclePoolTokenAbstract is KeydonixOracleAbstract {

    /**
     * @notice Reference to the ChainlinkedKeydonixOracleMainAssetAbstract contract
     */
    ChainlinkedKeydonixOracleMainAssetAbstract public uniswapOracleMainAsset;
}