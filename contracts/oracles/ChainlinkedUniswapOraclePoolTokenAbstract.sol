// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./ChainlinkedUniswapOracleMainAssetAbstract.sol";
import "./UniswapOracleAbstract.sol";


/**
 * @title ChainlinkedUniswapOraclePoolTokenAbstract
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract ChainlinkedUniswapOraclePoolTokenAbstract is UniswapOracleAbstract {

    ChainlinkedUniswapOracleMainAssetAbstract public uniswapOracleMainAsset;
}
