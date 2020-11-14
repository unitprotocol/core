// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/UniswapOracleAbstract.sol";
import "../vault-managers/VaultManagerParameters.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationAuction01
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages liquidation auction of position collateral
 **/
contract LiquidationAuction01 is ReentrancyGuard {
    using SafeMath for uint;

    uint public immutable DENOMINATOR_1E2 = 1e2;

    // vault manager parameters contract
    VaultManagerParameters public immutable vaultManagerParameters;

    // Vault contract
    Vault public immutable vault;

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidated(address indexed token, address indexed user);

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     **/
    constructor(address _vaultManagerParameters) public {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
    }

    /**
     * @dev Buyouts a position's collateral
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function buyout(address asset, address user) public nonReentrant {
        uint startingPrice = vault.liquidationPrice(asset, user);
        uint blocksPast = block.number.sub(vault.liquidationBlock(asset, user));
        uint devaluationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, user);
        uint penalty = debt.mul(vault.liquidationFee(asset, user)).div(DENOMINATOR_1E2);
        uint mainAssetInPosition = vault.collaterals(asset, user);
        uint colInPosition = vault.colToken(asset, user);

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
        // send liquidation command to the Vault
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
    ) {
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
}
