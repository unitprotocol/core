// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/ChainlinkedUniswapOracleLP.sol";
import "../helpers/ERC20Like.sol";


/**
 * @title LiquidatorUniswapLP
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
contract LiquidatorUniswapLP {
    using SafeMath for uint;

    // system parameters contract address
    Parameters public parameters;

    // Vault contract
    Vault public vault;

    // uniswap-based oracle contract
    ChainlinkedUniswapOracleLP public uniswapLPOracle;

    // liquidation system address
    address public liquidationSystem;

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidation(address indexed token, address indexed user);

    /**
     * @param _vault The address of the Vault
     * @param _uniswapOracle The address of Uniswap-based Oracle for LP tokens
     * @param _liquidationSystem The liquidation system's address
     **/
    constructor(
        address payable _vault,
        address _uniswapOracle,
        address _liquidationSystem
    )
        public
    {
        vault = Vault(_vault);
        parameters = vault.parameters();
        uniswapLPOracle = ChainlinkedUniswapOracleLP(_uniswapOracle);
        liquidationSystem = _liquidationSystem;
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param underlyingProof The proof data of underlying token price
     * @param colProof The proof data of COL token price
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
        view
        returns (bool)
    {
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        require(vault.oracleType(asset, user) == 2, "USDP: INCORRECT_ORACLE_TYPE");

        // USD value of the main collateral
        uint mainUsdValue = uniswapLPOracle.assetToUsd(asset, vault.collaterals(asset, user), underlyingProof);

        // USD value of the COL amount of a position
        uint colUsdValue = uniswapLPOracle.chainlinkedUniswapOracle().assetToUsd(vault.col(), vault.colToken(asset, user), colProof);

        return CR(mainUsdValue, colUsdValue, debt) >= LR(asset, mainUsdValue, colUsdValue);
    }

    /**
     * @notice Funds transfers directly to the liquidation system's address
     * @dev Triggers liquidation process
     * @param asset The address of the main collateral token of a position
     * @param underlyingProof The proof data of underlying token price
     * @param colProof The proof data of COL token price
     * @param user The owner of a position
     **/
    function liquidate(
        address asset,
        address user,
        UniswapOracle.ProofData memory underlyingProof,
        UniswapOracle.ProofData memory colProof
    )
        public
    {
        // reverts if a position is safe
        require(isLiquidatablePosition(asset, user, underlyingProof, colProof), "USDP: SAFE_POSITION");

        // sends liquidation command to the Vault
        vault.liquidate(asset, user, liquidationSystem);

        // fire an liquidation event
        emit Liquidation(asset, user);
    }

    /**
     * @dev Calculates position's collateral ratio
     * @param mainUsdValue USD value of main collateral in position
     * @param colUsdValue USD value of COL amount in position
     * @param debt USDP borrowed
     * @return collateralization ratio of a position
     **/
    function CR(uint mainUsdValue, uint colUsdValue, uint debt) public view returns (uint) {
        return debt.mul(100).mul(uniswapLPOracle.Q112()).div(mainUsdValue.add(colUsdValue));
    }

    /**
     * @dev Calculates position's liquidation ratio based on collateral proportion
     * @param asset The address of the main collateral token of a position
     * @param mainUsdValue USD value of main collateral in position
     * @param colUsdValue USD value of COL amount in position
     * @return liquidation ratio of a position
     **/
    function LR(address asset, uint mainUsdValue, uint colUsdValue) public view returns(uint) {
        uint lrMain = parameters.liquidationRatio(asset);
        uint lrCol = parameters.liquidationRatio(vault.col());

        return lrMain.mul(mainUsdValue).add(lrCol.mul(colUsdValue)).div(mainUsdValue.add(colUsdValue));
    }
}
