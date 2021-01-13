// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../Vault.sol";
import "../oracles/KeydonixOracleAbstract.sol";
import "../vault-managers/VaultManagerParameters.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationAuction02
 * @dev Manages liquidation auction of position collateral
 **/
contract LiquidationAuction02 is ReentrancyGuard {
    using SafeMath for uint;

    uint public constant DENOMINATOR_1E2 = 1e2;

    // vault manager parameters contract
    VaultManagerParameters public immutable vaultManagerParameters;

    // Vault contract
    Vault public immutable vault;

    /**
     * @dev Trigger when buyouts are happened
    **/
    event Buyout(address indexed token, address indexed owner, address indexed buyer, uint amount, uint price, uint penalty);

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
        require(vault.liquidationBlock(asset, user) != 0, "Unit Protocol: LIQUIDATION_NOT_TRIGGERED");
        uint startingPrice = vault.liquidationPrice(asset, user);
        uint blocksPast = block.number.sub(vault.liquidationBlock(asset, user));
        uint depreciationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, user);
        uint penalty = debt.mul(vault.liquidationFee(asset, user)).div(DENOMINATOR_1E2);
        uint collateralInPosition = vault.collaterals(asset, user);

        uint collateralToLiquidator;
        uint collateralToOwner;
        uint repayment;

        (collateralToLiquidator, collateralToOwner, repayment) = _calcLiquidationParams(
            depreciationPeriod,
            blocksPast,
            startingPrice,
            debt.add(penalty),
            collateralInPosition
        );

        _liquidate(
            asset,
            user,
            collateralToLiquidator,
            collateralToOwner,
            repayment,
            penalty
        );
    }

    function _liquidate(
        address asset,
        address user,
        uint collateralToBuyer,
        uint collateralToOwner,
        uint repayment,
        uint penalty
    ) private {
        // send liquidation command to the Vault
        vault.liquidate(
            asset,
            user,
            collateralToBuyer,
            0, // colToLiquidator
            collateralToOwner,
            0, // colToPositionOwner
            repayment,
            penalty,
            msg.sender
        );
        // fire an buyout event
        emit Buyout(asset, user, msg.sender, collateralToBuyer, repayment, penalty);
    }

    function _calcLiquidationParams(
        uint depreciationPeriod,
        uint blocksPast,
        uint startingPrice,
        uint debtWithPenalty,
        uint collateralInPosition
    )
    internal
    pure
    returns(
        uint collateralToBuyer,
        uint collateralToOwner,
        uint price
    ) {
        if (depreciationPeriod > blocksPast) {
            uint valuation = depreciationPeriod.sub(blocksPast);
            uint collateralPrice = startingPrice.mul(valuation).div(depreciationPeriod);
            if (collateralPrice > debtWithPenalty) {
                collateralToBuyer = collateralInPosition.mul(debtWithPenalty).div(collateralPrice);
                collateralToOwner = collateralInPosition.sub(collateralToBuyer);
                price = debtWithPenalty;
            } else {
                collateralToBuyer = collateralInPosition;
                price = collateralPrice;
            }
        } else {
            collateralToBuyer = collateralInPosition;
        }
    }
}
