// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../oracles/ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "../oracles/ChainlinkedKeydonixOraclePoolTokenAbstract.sol";
import "../helpers/IUniswapV2PairFull.sol";
import "../helpers/SafeMath.sol";

/**
 * @title KeydonixOraclePoolToken_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract KeydonixOraclePoolToken_Mock is ChainlinkedKeydonixOraclePoolTokenAbstract {
    using SafeMath for uint;

    constructor(address _keydonixOracleMainAsset_Mock) {
        uniswapOracleMainAsset = ChainlinkedKeydonixOracleMainAssetAbstract(_keydonixOracleMainAsset_Mock);
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount, ProofDataStruct memory /* proofData */) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        uint ePool; // current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve0;
        } else if (pair.token1() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve1;
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        uint lpSupply = pair.totalSupply();
        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112);

        return uniswapOracleMainAsset.ethToUsd(totalValueInEth_q112).div(lpSupply);
    }
}
