// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./Vault.sol";
import "./oracles/ChainlinkedUniswapOracle.sol";
import "./helpers/ERC20Like.sol";


/**
 * @title Liquidator
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
contract LiquidatorUniswap {
    using SafeMath for uint;

    // system parameters contract address
    Parameters public parameters;

    // Vault contract
    Vault public vault;

    // uniswap-based oracle contract
    ChainlinkedUniswapOracle public uniswapOracle;

    // COL token address
    address public COL;

    // liquidation system address
    address public liquidationSystem;

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidation(address indexed token, address indexed user);

    /**
     * @param _parameters The address of the system parameters
     * @param _vault The address of the Vault
     * @param _uniswapOracle The address of Uniswap-based Oracle
     * @param _col COL token address
     * @param _liquidationSystem The liquidation system's address
     **/
    constructor(address _parameters, address _vault, address _uniswapOracle, address _col, address _liquidationSystem) public {
        parameters = Parameters(_parameters);
        vault = Vault(_vault);
        uniswapOracle = ChainlinkedUniswapOracle(_uniswapOracle);
        COL = _col;
        liquidationSystem = _liquidationSystem;
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(address asset, address user, USDPLib.ProofData memory mainPriceProof, USDPLib.ProofData memory colPriceProof) public view returns (bool) {
        uint debt = vault.getDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        ChainlinkedUniswapOracle _usingOracle;

        // initially, only Uniswap is possible
        if (vault.oracleType(asset, user) == 1) {
            _usingOracle = uniswapOracle;
        } else revert("USDP: WRONG_ORACLE_TYPE");

        // USD value of the main collateral
        uint mainUsdValue = _usingOracle.assetToUsd(asset, vault.collaterals(asset, user), mainPriceProof);

        // USD value of the COL amount of a position
        uint colUsdValue = _usingOracle.assetToUsd(COL, vault.colToken(asset, user), colPriceProof);

        return CR(mainUsdValue, colUsdValue, debt) >= LR(asset, mainUsdValue, colUsdValue);
    }

    /**
     * @notice Funds transfers directly to the liquidation system's address
     * @dev Triggers liquidation process
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function liquidate(address asset, address user, USDPLib.ProofData memory mainPriceProof, USDPLib.ProofData memory colPriceProof) public {

        // reverts if a position is safe
        require(isLiquidatablePosition(asset, user, mainPriceProof, colPriceProof), "USDP: SAFE_POSITION");

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
    function CR(uint mainUsdValue, uint colUsdValue, uint debt) public pure returns (uint) {
        return debt.mul(100).div(mainUsdValue.add(colUsdValue));
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
        uint lrCol = parameters.liquidationRatio(parameters.COL());

        return lrMain.mul(mainUsdValue).add(lrCol.mul(colUsdValue)).div(mainUsdValue.add(colUsdValue)).div(2);
    }
}
