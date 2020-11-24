// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./LiquidationTriggerKeydonixAbstract.sol";
import "../helpers/ERC20Like.sol";
import "../oracles/ChainlinkedKeydonixOracleMainAssetAbstract.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationTriggerKeydonixMainAsset
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process triggering of main asset-based positions
 **/
contract LiquidationTriggerKeydonixMainAsset is LiquidationTriggerKeydonixAbstract, ReentrancyGuard {
    using SafeMath for uint;

    // uniswap-based oracle contract
    ChainlinkedKeydonixOracleMainAssetAbstract public immutable uniswapOracleMainAsset;

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _uniswapOracleMainAsset The address of Uniswap-based Oracle for main assets
     **/
    constructor(
        address _vaultManagerParameters,
        address _uniswapOracleMainAsset
    )
    public
    LiquidationTriggerKeydonixAbstract(_vaultManagerParameters, 1)
    {
        uniswapOracleMainAsset = ChainlinkedKeydonixOracleMainAssetAbstract(_uniswapOracleMainAsset);
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainProof The proof data of main collateral token price
     * @param colProof The proof data of COL token price
     **/
    function triggerLiquidation(
        address asset,
        address user,
        ChainlinkedKeydonixOracleMainAssetAbstract.ProofDataStruct memory mainProof,
        ChainlinkedKeydonixOracleMainAssetAbstract.ProofDataStruct memory colProof
    )
    public
    override
    nonReentrant
    {
        // USD value of the main collateral
        uint mainUsdValue_q112 = uniswapOracleMainAsset.assetToUsd(asset, vault.collaterals(asset, user), mainProof);

        // USD value of the COL amount of a position
        uint colUsdValue_q112 = uniswapOracleMainAsset.assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        // reverts if a position is not liquidatable
        require(isLiquidatablePosition(asset, user, mainUsdValue_q112, colUsdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = mainUsdValue_q112.add(colUsdValue_q112).mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = mainUsdValue_q112.add(colUsdValue_q112).sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, user, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, user);
    }
}
