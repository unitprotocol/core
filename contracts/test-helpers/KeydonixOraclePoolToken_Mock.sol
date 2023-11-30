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
 * @dev Mock contract for calculating the USD price of pool tokens in tests.
 */
contract KeydonixOraclePoolToken_Mock is ChainlinkedKeydonixOraclePoolTokenAbstract {
    using SafeMath for uint;

    /**
     * @dev Constructor for KeydonixOraclePoolToken_Mock.
     * @param _keydonixOracleMainAsset_Mock Address of the Keydonix Oracle Main Asset mock contract.
     */
    constructor(address _keydonixOracleMainAsset_Mock) {
        uniswapOracleMainAsset = ChainlinkedKeydonixOracleMainAssetAbstract(_keydonixOracleMainAsset_Mock);
    }

    /**
     * @notice Converts an amount of asset into USD value based on the stored oracle prices.
     * @dev Mock function for converting asset to USD. Overrides the base function for testing purposes.
     * @param asset The address of the Uniswap V2 pair token to convert.
     * @param amount The amount of the asset to convert.
     * @param /* proofData */ This parameter is ignored in the mock implementation.
     * @return uint The equivalent USD value of the given asset amount.
     * @dev Throws if the provided asset is not a registered pair with WETH.
     */
    function assetToUsd(address asset, uint amount, ProofDataStruct memory /* proofData */) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        uint ePool; // Current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve0;
        } else if (pair.token1() == uniswapOracleMainAsset.WETH()) {
            ePool = _reserve1;
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112).div(pair.totalSupply());

        return uniswapOracleMainAsset.ethToUsd(totalValueInEth_q112);
    }
}