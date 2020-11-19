// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./LiquidationTriggerKeydonixAbstract.sol";
import "../Vault.sol";
import "../oracles/ChainlinkedKeydonixOraclePoolTokenAbstract.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationTriggerKeydonixPoolToken
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process triggering of LP-tokens-based positions
 **/
contract LiquidationTriggerKeydonixPoolToken is LiquidationTriggerKeydonixAbstract, ReentrancyGuard {
    using SafeMath for uint;

    // uniswap-based oracle contract
    ChainlinkedKeydonixOraclePoolTokenAbstract public immutable uniswapOraclePool;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _uniswapOraclePoolToken The address of Uniswap-based Oracle for LP tokens
     **/
    constructor(
        address _vaultManagerParameters,
        address _uniswapOraclePoolToken
    )
    public
    LiquidationTriggerKeydonixAbstract(_vaultManagerParameters, 2)
    {
        uniswapOraclePool = ChainlinkedKeydonixOraclePoolTokenAbstract(_uniswapOraclePoolToken);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param underlyingProof The proof data of underlying token price
     * @param colProof The proof data of COL token price
     **/
    function triggerLiquidation(
        address asset,
        address user,
        ChainlinkedKeydonixOraclePoolTokenAbstract.ProofDataStruct calldata underlyingProof,
        ChainlinkedKeydonixOraclePoolTokenAbstract.ProofDataStruct calldata colProof
    )
    external
    override
    nonReentrant
    {
        // USD value of the main collateral
        uint mainUsdValue_q112 = uniswapOraclePool.assetToUsd(asset, vault.collaterals(asset, user), underlyingProof);

        // USD value of the COL amount of a position
        uint colUsdValue_q112 = uniswapOraclePool.keydonixOracleMainAsset().assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        // reverts if a position is safe
        require(isLiquidatablePosition(asset, user, mainUsdValue_q112, colUsdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = mainUsdValue_q112.add(colUsdValue_q112).mul(vaultManagerParameters.liquidationDiscount(asset)).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = mainUsdValue_q112.add(colUsdValue_q112).sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, user, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, user);
    }
}
