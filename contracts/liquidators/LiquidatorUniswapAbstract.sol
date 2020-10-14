// SPDX-License-Identifier: bsl-1.1


import "../Vault.sol";

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;
import "../oracles/UniswapOracleAbstract.sol";



/**
 * @title LiquidatorUniswap
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
abstract contract LiquidatorUniswapAbstract {
    using SafeMath for uint;

    uint public constant Q112 = 2**112;

    // system parameters contract address
    Parameters public parameters;

    uint public oracleType;

    // Vault contract
    Vault public vault;

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidation(address indexed token, address indexed user);

    /**
     * @param _vault The address of the Vault
     * @param _vault The id of the oracle type
     **/
    constructor(
        address payable _vault,
        uint _oracleType
    )
        public
    {
        vault = Vault(_vault);
        parameters = vault.parameters();
        oracleType = _oracleType;
    }

    /**
     * @dev Liquidates position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param assetProof The proof data of asset token price
     * @param colProof The proof data of COL token price
     **/
    function liquidate(
        address asset,
        address user,
        UniswapOracleAbstract.ProofDataStruct calldata assetProof,
        UniswapOracleAbstract.ProofDataStruct calldata colProof
    )
        external
        virtual
    {
    }


    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param mainUsdValue_q112 Q112-encoded USD value of the main collateral
     * @param colUsdValue_q112 Q112-encoded USD value of the COL amount
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        uint mainUsdValue_q112,
        uint colUsdValue_q112
    )
        public
        view
        returns (bool)
    {
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        require(vault.oracleType(asset, user) == oracleType, "USDP: INCORRECT_ORACLE_TYPE");

        return UR(mainUsdValue_q112, colUsdValue_q112, debt) >= LR(asset, mainUsdValue_q112, colUsdValue_q112);
    }

    /**
     * @dev Calculates position's utilization ratio
     * @param mainUsdValue USD value of main collateral
     * @param colUsdValue USD value of COL amount
     * @param debt USDP borrowed
     * @return utilization ratio of a position
     **/
    function UR(uint mainUsdValue, uint colUsdValue, uint debt) public pure returns (uint) {
        return debt.mul(100).mul(Q112).div(mainUsdValue.add(colUsdValue));
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
