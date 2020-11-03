// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/UniswapOracleAbstract.sol";
import "../vault-managers/VaultManagerParameters.sol";


/**
 * @title LiquidatorUniswap
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation process
 **/
abstract contract LiquidatorUniswapAbstract {
    using SafeMath for uint;

    uint public constant Q112 = 2**112;
    uint public constant DENOMINATOR_1E5 = 1e5;
    uint public constant DENOMINATOR_1E2 = 1e2;

    // vault manager parameters contract
    VaultManagerParameters public vaultManagerParameters;

    uint public oracleType;

    // Vault contract
    Vault public vault;

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed token, address indexed user);

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidated(address indexed token, address indexed user);

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _oracleType The id of the oracle type
     **/
    constructor(address _vaultManagerParameters, uint _oracleType) {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(vaultManagerParameters.vaultParameters().vault());
        oracleType = _oracleType;
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param assetProof The proof data of asset token price
     * @param colProof The proof data of COL token price
     **/
    function triggerLiquidation(
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
     * @dev Liquidates a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(
        address asset,
        address user
    )
        public
    {
        uint startingPrice = vault.liquidationPrice(asset, user);
        uint blocksPast = block.number.sub(vault.liquidationBlock(asset, user));
        uint devaluationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, user);
        uint penalty = debt.mul(vault.liquidationFee(asset, user)).div(DENOMINATOR_1E2);
        

        uint mainAssetInPosition = vault.collaterals(asset, user);
        uint colInPosition = vault.collaterals(asset, user);
        
        uint mainToLiquidator;
        uint colToLiquidator;
        uint mainToOwner;
        uint colToOwner;
        uint repayment;
        
        (mainToLiquidator, colToLiquidator, mainToOwner, colToOwner, repayment) = _calcLiquidationParams(
            devaluationPeriod,
            blocksPast,
            startingPrice,
            debt.add(penalty),
            mainAssetInPosition,
            colInPosition
        );
        
        // send liquidation command to the Vault
        _liquidate(
            asset,
            user,
            mainToLiquidator,
            colToLiquidator,
            mainToOwner,
            colToOwner,
            repayment,
            penalty
        );
    }
    
    function _liquidate(
        address asset,
        address user,
        uint mainAssetToLiquidator,
        uint colToLiquidator,
        uint mainAssetToPositionOwner,
        uint colToPositionOwner,
        uint repayment,
        uint penalty
    ) private {
        vault.liquidate(
            asset,
            user,
            mainAssetToLiquidator,
            colToLiquidator,
            mainAssetToPositionOwner,
            colToPositionOwner,
            repayment,
            penalty,
            msg.sender
        );
        

        // fire an liquidation event
        emit Liquidated(asset, user);
    }
    
    function _calcLiquidationParams(
        uint devaluationPeriod,
        uint blocksPast,
        uint startingPrice,
        uint debtWithPenalty,
        uint mainAssetInPosition,
        uint colInPosition
    ) 
        internal
        pure 
        returns(
            uint mainToLiquidator, 
            uint colToLiquidator, 
            uint mainToOwner, 
            uint colToOwner, 
            uint repayment
        )
    {
        if (devaluationPeriod > blocksPast) {
            uint valuation = devaluationPeriod.sub(blocksPast);
            uint collateralPrice = startingPrice.mul(valuation).div(devaluationPeriod);
            if (collateralPrice > debtWithPenalty) {
                uint ownerShare = collateralPrice.sub(debtWithPenalty);
                mainToLiquidator = mainAssetInPosition.mul(debtWithPenalty).div(collateralPrice);
                colToLiquidator = colInPosition.mul(debtWithPenalty).div(collateralPrice);
                mainToOwner = mainAssetInPosition.mul(ownerShare).div(collateralPrice);
                colToOwner = colInPosition.mul(ownerShare).div(collateralPrice);
                repayment = debtWithPenalty;
            } else {
                mainToLiquidator = mainAssetInPosition;
                colToLiquidator = colInPosition;
                repayment = collateralPrice;
            }
        } else {
            mainToLiquidator = mainAssetInPosition;
            colToLiquidator = colInPosition;
        }
        
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
        uint lrMain = vaultManagerParameters.liquidationRatio(asset);
        uint lrCol = vaultManagerParameters.liquidationRatio(vault.col());

        return lrMain.mul(mainUsdValue).add(lrCol.mul(colUsdValue)).div(mainUsdValue.add(colUsdValue));
    }
}
