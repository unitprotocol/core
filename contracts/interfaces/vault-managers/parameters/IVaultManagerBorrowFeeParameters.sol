// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IVaultManagerBorrowFeeParameters {

    function BORROW_FEE_100_PERCENT() external view returns (uint);

    /**
     * @notice Borrow fee receiver
     **/
    function feeReceiver() external view returns (address);

    /**
     * @notice Sets the borrow fee receiver. Only manager is able to call this function
     * @param newFeeReceiver The address of fee receiver
     **/
    function setFeeReceiver(address newFeeReceiver) external;

    /**
     * @notice Sets the base percentage of borrow fee. Only manager is able to call this function
     * @param newBaseBorrowFee The borrow fee percentage (3 decimals)
     **/
    function setBaseBorrowFeePercent(uint32 newBaseBorrowFee) external;

    /**
     * @notice Sets the percentage of the borrow fee for a particular collateral. Only manager is able to call this function
     * @param asset The address of the main collateral token
     * @param newEnabled Is custom fee enabled for asset
     * @param newFee The borrow fee percentage (3 decimals)
     **/
    function setAssetBorrowFeePercent(address asset, bool newEnabled, uint32 newFee) external;

    /**
     * @notice Returns borrow fee percentage for particular collateral
     * @param asset The address of the main collateral token
     * @return The borrow fee percentage (3 decimals)
     **/
    function getBorrowFeePercent(address asset) external view returns (uint32);

    /**
     * @notice Returns borrow fee for usdp amount for particular collateral
     * @param asset The address of the main collateral token
     * @return The borrow fee
     **/
    function calcBorrowFee(address asset, uint usdpAmount) external view returns (uint);
}
