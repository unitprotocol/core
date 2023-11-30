// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IVault
 * @dev Interface for the Vault contract in Unit Protocol.
 */
interface IVault {
    /**
     * @dev Returns the denominator for calculations with precision to 2 decimal places.
     * @return The denominator for percentage calculations.
     */
    function DENOMINATOR_1E2() external view returns (uint256);

    /**
     * @dev Returns the denominator for calculations with precision to 5 decimal places.
     * @return The denominator for high precision calculations.
     */
    function DENOMINATOR_1E5() external view returns (uint256);

    /**
     * @dev Allows users to borrow specified amount of asset.
     * @param asset The address of the asset to borrow.
     * @param user The address of the user borrowing the asset.
     * @param amount The amount of the asset to borrow.
     * @return The actual amount borrowed.
     */
    function borrow(address asset, address user, uint256 amount) external returns (uint256);

    /**
     * @dev Calculates the fee for borrowing.
     * @param asset The address of the borrowed asset.
     * @param user The address of the user that borrowed the asset.
     * @param amount The amount of the asset borrowed.
     * @return The fee associated with the borrowing.
     */
    function calculateFee(address asset, address user, uint256 amount) external view returns (uint256);

    /**
     * @dev Changes the oracle type for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @param newOracleType The new oracle type identifier.
     */
    function changeOracleType(address asset, address user, uint256 newOracleType) external;

    /**
     * @dev Charges the fee for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @param amount The amount to be charged as fee.
     */
    function chargeFee(address asset, address user, uint256 amount) external;

    /**
     * @dev Returns the address of the collateral token.
     * @return The address of the collateral token.
     */
    function col() external view returns (address);

    /**
     * @dev Returns the amount of collateral token for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The amount of collateral token.
     */
    function colToken(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the amount of collateral for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The amount of collateral.
     */
    function collaterals(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the debt of a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The debt amount.
     */
    function debts(address asset, address user) external view returns (uint256);

    /**
     * @dev Allows users to deposit collateral token.
     * @param asset The address of the asset.
     * @param user The address of the user depositing collateral.
     * @param amount The amount of collateral to deposit.
     */
    function depositCol(address asset, address user, uint256 amount) external;

    /**
     * @dev Allows users to deposit ETH as collateral.
     * @param user The address of the user depositing ETH.
     */
    function depositEth(address user) external payable;

    /**
     * @dev Allows users to deposit main collateral token.
     * @param asset The address of the asset.
     * @param user The address of the user depositing collateral.
     * @param amount The amount of main collateral token to deposit.
     */
    function depositMain(address asset, address user, uint256 amount) external;

    /**
     * @dev Destroys the position for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     */
    function destroy(address asset, address user) external;

    /**
     * @dev Returns the total debt for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The total debt amount.
     */
    function getTotalDebt(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the timestamp of the last update for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The timestamp of the last update.
     */
    function lastUpdate(address asset, address user) external view returns (uint256);

    /**
     * @dev Liquidates a position.
     * @param asset The address of the asset.
     * @param positionOwner The address of the position owner.
     * @param mainAssetToLiquidator The amount of main asset to be sent to the liquidator.
     * @param colToLiquidator The amount of collateral to be sent to the liquidator.
     * @param mainAssetToPositionOwner The amount of main asset to be returned to the position owner.
     * @param colToPositionOwner The amount of collateral to be returned to the position owner.
     * @param repayment The amount of debt to be repaid.
     * @param penalty The penalty fee for liquidation.
     * @param liquidator The address of the liquidator.
     */
    function liquidate(
        address asset,
        address positionOwner,
        uint256 mainAssetToLiquidator,
        uint256 colToLiquidator,
        uint256 mainAssetToPositionOwner,
        uint256 colToPositionOwner,
        uint256 repayment,
        uint256 penalty,
        address liquidator
    ) external;

    /**
     * @dev Returns the block number when liquidation was triggered for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The block number of the liquidation trigger.
     */
    function liquidationBlock(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the liquidation fee for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The liquidation fee amount.
     */
    function liquidationFee(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the liquidation price for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The liquidation price.
     */
    function liquidationPrice(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the oracle type for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The oracle type identifier.
     */
    function oracleType(address asset, address user) external view returns (uint256);

    /**
     * @dev Allows users to repay part of the debt.
     * @param asset The address of the asset.
     * @param user The address of the user repaying the debt.
     * @param amount The amount to be repaid.
     * @return The actual amount repaid.
     */
    function repay(address asset, address user, uint256 amount) external returns (uint256);

    /**
     * @dev Creates a new position for a given asset and user with a specific oracle type.
     * @param asset The address of the asset.
     * @param user The address of the user spawning the position.
     * @param _oracleType The oracle type identifier.
     */
    function spawn(address asset, address user, uint256 _oracleType) external;

    /**
     * @dev Returns the stability fee for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     * @return The stability fee amount.
     */
    function stabilityFee(address asset, address user) external view returns (uint256);

    /**
     * @dev Returns the total token debt for a given asset.
     * @param asset The address of the asset.
     * @return The total token debt.
     */
    function tokenDebts(address asset) external view returns (uint256);

    /**
     * @dev Triggers liquidation for a given asset and user at an initial price.
     * @param asset The address of the asset.
     * @param positionOwner The address of the position owner.
     * @param initialPrice The initial price for liquidation.
     */
    function triggerLiquidation(address asset, address positionOwner, uint256 initialPrice) external;

    /**
     * @dev Updates the position for a given asset and user.
     * @param asset The address of the asset.
     * @param user The address of the user.
     */
    function update(address asset, address user) external;

    /**
     * @dev Returns the address of the USD pegged token.
     * @return The address of the USD pegged token.
     */
    function usdp() external view returns (address);

    /**
     * @dev Returns the address of the vault parameters contract.
     * @return The address of the vault parameters contract.
     */
    function vaultParameters() external view returns (address);

    /**
     * @dev Returns the address of the wrapped ETH token.
     * @return The address of the wrapped ETH token.
     */
    function weth() external view returns (address payable);

    /**
     * @dev Allows users to withdraw collateral token.
     * @param asset The address of the asset.
     * @param user The address of the user withdrawing collateral.
     * @param amount The amount of collateral to withdraw.
     */
    function withdrawCol(address asset, address user, uint256 amount) external;

    /**
     * @dev Allows users to withdraw ETH.
     * @param user The address of the user withdrawing ETH.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawEth(address user, uint256 amount) external;

    /**
     * @dev Allows users to withdraw main collateral token.
     * @param asset The address of the asset.
     * @param user The address of the user withdrawing collateral.
     * @param amount The amount of main collateral token to withdraw.
     */
    function withdrawMain(address asset, address user, uint256 amount) external;
}