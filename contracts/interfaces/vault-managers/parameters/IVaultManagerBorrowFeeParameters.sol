// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IVaultManagerBorrowFeeParameters
 * @dev Interface for managing borrow fee parameters in a vault.
 */
interface IVaultManagerBorrowFeeParameters {

    /**
     * @dev Returns the constant representing the number of basis points in one.
     * @return The number of basis points in one.
     */
    function BASIS_POINTS_IN_1() external view returns (uint);

    /**
     * @dev Returns the address where borrow fees are sent.
     * @return The address of the fee receiver.
     */
    function feeReceiver() external view returns (address);

    /**
     * @dev Sets the address that receives the borrow fee.
     * @param newFeeReceiver The address of the new fee receiver.
     * @notice Only the manager can call this function.
     */
    function setFeeReceiver(address newFeeReceiver) external;

    /**
     * @dev Sets the base borrow fee in basis points.
     * @param newBaseBorrowFeeBasisPoints The new borrow fee in basis points.
     * @notice Only the manager can call this function.
     */
    function setBaseBorrowFee(uint16 newBaseBorrowFeeBasisPoints) external;

    /**
     * @dev Sets the borrow fee for a specific collateral in basis points.
     * @param asset The address of the collateral token.
     * @param newEnabled Determines if the custom fee is enabled for the asset.
     * @param newFeeBasisPoints The new borrow fee in basis points.
     * @notice Only the manager can call this function.
     */
    function setAssetBorrowFee(address asset, bool newEnabled, uint16 newFeeBasisPoints) external;

    /**
     * @dev Retrieves the borrow fee for a specific collateral in basis points.
     * @param asset The address of the collateral token.
     * @return feeBasisPoints The borrow fee in basis points.
     */
    function getBorrowFee(address asset) external view returns (uint16 feeBasisPoints);

    /**
     * @dev Calculates the borrow fee amount in USDP for a given amount and collateral.
     * @param asset The address of the collateral token.
     * @param usdpAmount The amount of USDP for which to calculate the fee.
     * @return The calculated borrow fee.
     */
    function calcBorrowFeeAmount(address asset, uint usdpAmount) external view returns (uint);
}