// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./LiquidatorUniswapAbstract.sol";
import "../helpers/ERC20Like.sol";
import "../oracles/ChainlinkedUniswapOracleMainAssetAbstract.sol";


/**
 * @title LiquidatorUniswapMainAsset
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
contract LiquidatorUniswapMainAsset is LiquidatorUniswapAbstract {

    // uniswap-based oracle contract
    ChainlinkedUniswapOracleMainAssetAbstract public uniswapOracleMainAsset;

    /**
     * @param _vault The address of the Vault
     * @param _uniswapOracleMainAsset The address of Uniswap-based Oracle for main assets
     **/
    constructor(
        address payable _vault,
        address _uniswapOracleMainAsset
    )
        public
        LiquidatorUniswapAbstract(_vault, 1)
    {
        uniswapOracleMainAsset = ChainlinkedUniswapOracleMainAssetAbstract(_uniswapOracleMainAsset);
    }

    /**
     * @dev Liquidates position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainProof The proof data of main collateral token price
     * @param colProof The proof data of COL token price
     **/
    function liquidate(
        address asset,
        address user,
        ChainlinkedUniswapOracleMainAssetAbstract.ProofDataStruct memory mainProof,
        ChainlinkedUniswapOracleMainAssetAbstract.ProofDataStruct memory colProof
    )
        public
        override
    {
        // USD value of the main collateral
        uint mainUsdValue_q112 = uniswapOracleMainAsset.assetToUsd(asset, vault.collaterals(asset, user), mainProof);

        // USD value of the COL amount of a position
        uint colUsdValue_q112 = uniswapOracleMainAsset.assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        // reverts if a position is not liquidatable
        require(isLiquidatablePosition(asset, user, mainUsdValue_q112, colUsdValue_q112), "USDP: SAFE_POSITION");

        // sends liquidation command to the Vault
        vault.liquidate(asset, user, msg.sender, mainUsdValue_q112.add(colUsdValue_q112).div(Q112));

        // fire an liquidation event
        emit Liquidation(asset, user);
    }
}
