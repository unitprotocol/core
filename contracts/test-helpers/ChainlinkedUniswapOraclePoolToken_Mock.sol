// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "../oracles/ChainlinkedUniswapOracleMainAssetAbstract.sol";
import "../oracles/ChainlinkedUniswapOraclePoolTokenAbstract.sol";
import "../helpers/IUniswapV2PairFull.sol";
import "../helpers/SafeMath.sol";

/**
 * @title ChainlinkedUniswapOraclePoolToken_Mock
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Calculates the USD price of desired tokens
 **/
contract ChainlinkedUniswapOraclePoolToken_Mock is ChainlinkedUniswapOraclePoolTokenAbstract {
    using SafeMath for uint;

    constructor(address _uniswapOracleMainAsset_Mock) public {
        uniswapOracleMainAsset = ChainlinkedUniswapOracleMainAssetAbstract(_uniswapOracleMainAsset_Mock);
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount, ProofDataStruct memory proofData) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        uint ePool; // current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve0;
        } else if (pair.token1() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve1;
        } else {
            revert("USDP: NOT_REGISTERED_PAIR");
        }

        uint lpSupply = pair.totalSupply();
        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112);

        return uniswapOracleMainAsset.ethToUsd(totalValueInEth_q112).div(lpSupply);
    }
}
