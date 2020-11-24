// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "./KeydonixOracleAbstract.sol";


/**
 * @title ChainlinkedKeydonixOraclePoolTokenAbstract
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract ChainlinkedKeydonixOraclePoolTokenAbstract is KeydonixOracleAbstract {

    ChainlinkedKeydonixOracleMainAssetAbstract public uniswapOracleMainAsset;
}
