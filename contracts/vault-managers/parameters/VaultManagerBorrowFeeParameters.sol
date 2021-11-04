// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../VaultParameters.sol";
import "../../interfaces/vault-managers/parameters/IVaultManagerBorrowFeeParameters.sol";
import "../../helpers/SafeMath.sol";


/**
 * @title VaultManagerBorrowFeeParameters
 **/
contract VaultManagerBorrowFeeParameters is Auth, IVaultManagerBorrowFeeParameters {
    using SafeMath for uint;

    uint public constant override BORROW_FEE_100_PERCENT = 1e5;

    struct AssetBorrowFeeParams {
        bool enabled; // is custom fee for asset enabled
        uint32 feePercent; // 3 decimals
    }

    // map token to borrow fee percentage;
    mapping(address => AssetBorrowFeeParams) public assetBorrowFee;
    uint32 public baseBorrowFeePercent;

    address public override feeReceiver;

    event AssetBorrowFeeParamsEnabled(address asset, uint32 feePercent);
    event AssetBorrowFeeParamsDisabled(address asset);

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    modifier correctFee(uint32 fee) {
        require(fee < BORROW_FEE_100_PERCENT, "Unit Protocol: INCORRECT_FEE_VALUE");
        _;
    }

    constructor(address _vaultParameters, uint32 _baseBorrowFeePercent, address _feeReceiver)
        Auth(_vaultParameters)
        nonZeroAddress(_feeReceiver)
        correctFee(_baseBorrowFeePercent)
    {
        baseBorrowFeePercent = _baseBorrowFeePercent;
        feeReceiver = _feeReceiver;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setFeeReceiver(address newFeeReceiver) external override onlyManager nonZeroAddress(newFeeReceiver) {
        feeReceiver = newFeeReceiver;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setBaseBorrowFeePercent(uint32 newBaseBorrowFeePercent) external override onlyManager correctFee(newBaseBorrowFeePercent) {
        baseBorrowFeePercent = newBaseBorrowFeePercent;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setAssetBorrowFeePercent(address asset, bool newEnabled, uint32 newFeePercent) external override onlyManager correctFee(newFeePercent) {
        assetBorrowFee[asset].enabled = newEnabled;
        assetBorrowFee[asset].feePercent = newFeePercent;

        if (newEnabled) {
            emit AssetBorrowFeeParamsEnabled(asset, newFeePercent);
        } else {
            emit AssetBorrowFeeParamsDisabled(asset);
        }
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function getBorrowFeePercent(address asset) public override view returns (uint32) {
        if (assetBorrowFee[asset].enabled) {
            return assetBorrowFee[asset].feePercent;
        }

        return baseBorrowFeePercent;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function calcBorrowFee(address asset, uint usdpAmount) external override view returns (uint) {
        uint32 borrowFeePercent = getBorrowFeePercent(asset);
        if (borrowFeePercent == 0) {
            return 0;
        }

        return usdpAmount.mul(uint(borrowFeePercent)).div(BORROW_FEE_100_PERCENT);
    }
}
