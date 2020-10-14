// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./LiquidatorUniswapAbstract.sol";
import "../Vault.sol";
import "../oracles/ChainlinkedUniswapOraclePoolTokenAbstract.sol";
import "../helpers/ERC20Like.sol";


/**
 * @title LiquidatorUniswapPoolToken
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
contract LiquidatorUniswapPoolToken is LiquidatorUniswapAbstract {

    // uniswap-based oracle contract
    ChainlinkedUniswapOraclePoolTokenAbstract public uniswapOraclePool;

    /**
     * @param _vault The address of the Vault
     * @param _uniswapOraclePoolToken The address of Uniswap-based Oracle for LP tokens
     **/
    constructor(
        address payable _vault,
        address _uniswapOraclePoolToken
    )
        public
        LiquidatorUniswapAbstract(_vault, 2)
    {
        vault = Vault(_vault);
        parameters = vault.parameters();
        uniswapOraclePool = ChainlinkedUniswapOraclePoolTokenAbstract(_uniswapOraclePoolToken);
    }

    /**
     * @dev Liquidates position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param underlyingProof The proof data of underlying token price
     * @param colProof The proof data of COL token price
     **/
    function liquidate(
        address asset,
        address user,
        ChainlinkedUniswapOraclePoolTokenAbstract.ProofDataStruct calldata underlyingProof,
        ChainlinkedUniswapOraclePoolTokenAbstract.ProofDataStruct calldata colProof
    )
        external
        override
    {
        // USD value of the main collateral
        uint mainUsdValue_q112 = uniswapOraclePool.assetToUsd(asset, vault.collaterals(asset, user), underlyingProof);

        // USD value of the COL amount of a position
        uint colUsdValue_q112 = uniswapOraclePool.uniswapOracleMainAsset().assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        // reverts if a position is safe
        require(isLiquidatablePosition(asset, user, mainUsdValue_q112, colUsdValue_q112), "USDP: SAFE_POSITION");

        // sends liquidation command to the Vault
        vault.liquidate(asset, user, msg.sender, mainUsdValue_q112.add(colUsdValue_q112).div(Q112));

        // fire an liquidation event
        emit Liquidation(asset, user);
    }
}
