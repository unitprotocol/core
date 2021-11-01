// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../VaultParameters.sol";
import "../../interfaces/parameters/IVaultManagerBorrowFeeParameters.sol";


/**
 * @title VaultManagerBorrowFeeParameters
 **/
contract VaultManagerBorrowFeeParameters is Auth, IVaultManagerBorrowFeeParameters {

    uint32 public constant override BORROW_FEE_100_PERCENT = 1e5;

    struct assetBorrowFeeParams {
        bool enabled; // is custom fee for asset enabled
        uint32 feePercent; // 3 decimals
    }

    // map token to borrow fee percentage;
    mapping(address => assetBorrowFeeParams) public assetBorrowFee;
    uint32 public baseBorrowFee;

    address public override feeReceiver;

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    modifier correctFee(uint32 fee) {
        require(fee < BORROW_FEE_100_PERCENT, "Unit Protocol: INCORRECT_FEE_VALUE");
        _;
    }

    constructor(address _vaultParameters, uint32 _baseBorrowFee, address _feeReceiver)
        Auth(_vaultParameters)
        nonZeroAddress(_feeReceiver)
        correctFee(_baseBorrowFee)
    {
        baseBorrowFee = _baseBorrowFee;
        feeReceiver = _feeReceiver;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setFeeReceiver(address newFeeReceiver) external override onlyManager nonZeroAddress(newFeeReceiver) {
        feeReceiver = newFeeReceiver;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setBaseBorrowFee(uint32 newBaseBorrowFee) external override onlyManager correctFee(newBaseBorrowFee) {
        baseBorrowFee = newBaseBorrowFee;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setAssetBorrowFee(address asset, bool newEnabled, uint32 newFee) external override onlyManager correctFee(newFee) {
        assetBorrowFee[asset].enabled = newEnabled;
        assetBorrowFee[asset].feePercent = newFee;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function getBorrowFee(address asset) external override view returns (uint32) {
        if (assetBorrowFee[asset].enabled) {
            return assetBorrowFee[asset].feePercent;
        }

        return baseBorrowFee;
    }
}
