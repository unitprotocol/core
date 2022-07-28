// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import '../interfaces/IOracleRegistry.sol';
import '../interfaces/IVault.sol';
import '../interfaces/ICDPRegistry.sol';
import '../interfaces/vault-managers/parameters/IVaultManagerParameters.sol';
import '../interfaces/vault-managers/parameters/IAssetsBooleanParameters.sol';
import '../interfaces/IVaultParameters.sol';
import '../interfaces/IWrappedToUnderlyingOracle.sol';
import '../vault-managers/parameters/AssetParameters.sol';

import '../helpers/ReentrancyGuard.sol';
import '../helpers/SafeMath.sol';

/**
 * @title LiquidationAuction02
 **/
contract LiquidationAuction02 is ReentrancyGuard {
    using SafeMath for uint;

    IVault public immutable vault;
    IVaultManagerParameters public immutable vaultManagerParameters;
    ICDPRegistry public immutable cdpRegistry;
    IAssetsBooleanParameters public immutable assetsBooleanParameters;

    uint public constant DENOMINATOR_1E2 = 1e2;
    uint public constant WRAPPED_TO_UNDERLYING_ORACLE_TYPE = 11;

    /**
     * @dev Trigger when buyouts are happened
    **/
    event Buyout(address indexed asset, address indexed owner, address indexed buyer, uint amount, uint price, uint penalty);

    modifier checkpoint(address asset, address owner) {
        _;
        cdpRegistry.checkpoint(asset, owner);
    }

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _cdpRegistry The address of the CDP registry
     * @param _assetsBooleanParameters The address of the AssetsBooleanParameters
     **/
    constructor(address _vaultManagerParameters, address _cdpRegistry, address _assetsBooleanParameters) {
        require(
            _vaultManagerParameters != address(0) &&
            _cdpRegistry != address(0) &&
            _assetsBooleanParameters != address(0),
            "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        vault = IVault(IVaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        cdpRegistry = ICDPRegistry(_cdpRegistry);
        assetsBooleanParameters = IAssetsBooleanParameters(_assetsBooleanParameters);
    }

    /**
     * @dev Buyouts a position's collateral
     * @param asset The address of the main collateral token of a position
     * @param owner The owner of a position
     **/
    function buyout(address asset, address owner) public nonReentrant checkpoint(asset, owner) {
        require(vault.liquidationTs(asset, owner) != 0, "Unit Protocol: LIQUIDATION_NOT_TRIGGERED");
        uint startingPrice = vault.liquidationPrice(asset, owner);
        uint secondsPassed = block.timestamp.sub(vault.liquidationTs(asset, owner));
        uint depreciationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, owner);
        uint penalty = debt.mul(vault.liquidationFee(asset, owner)).div(DENOMINATOR_1E2);
        uint collateralInPosition = vault.collaterals(asset, owner);

        uint collateralToLiquidator;
        uint collateralToOwner;
        uint repayment;

        (collateralToLiquidator, collateralToOwner, repayment) = _calcLiquidationParams(
            depreciationPeriod,
            secondsPassed,
            startingPrice,
            debt.add(penalty),
            collateralInPosition
        );

        uint256 assetBoolParams = assetsBooleanParameters.getAll(asset);

        // ensure that at least 1 unit of token is transferred to cdp owner
        if (collateralToOwner == 0 && AssetParameters.needForceTransferAssetToOwnerOnLiquidation(assetBoolParams)) {
            collateralToOwner = 1;
            collateralToLiquidator = collateralToLiquidator.sub(1);
        }

        _liquidate(
            asset,
            owner,
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
            collateralToOwner,
            repayment,
            penalty,
            msg.sender
        );

        // fire an buyout event
        emit Buyout(asset, user, msg.sender, collateralToBuyer, repayment, penalty);
    }

    function _calcLiquidationParams(
        uint depreciationPeriod,
        uint secondsPassed,
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
        if (depreciationPeriod > secondsPassed) {
            uint valuation = depreciationPeriod.sub(secondsPassed);
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
