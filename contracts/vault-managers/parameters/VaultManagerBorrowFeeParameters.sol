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

    uint public constant override BASIS_POINTS_IN_1 = 1e4;

    struct AssetBorrowFeeParams {
        bool enabled; // is custom fee for asset enabled
        uint16 feeBasisPoints; // fee basis points, 1 basis point = 0.0001
    }

    // map token to borrow fee
    mapping(address => AssetBorrowFeeParams) public assetBorrowFee;
    uint16 public baseBorrowFeeBasisPoints;

    address public override feeReceiver;

    event AssetBorrowFeeParamsEnabled(address indexed asset, uint16 feeBasisPoints);
    event AssetBorrowFeeParamsDisabled(address indexed asset);
    event FeeReceiverChanged(address indexed newFeeReceiver);
    event BaseBorrowFeeChanged(uint16 newBaseBorrowFeeBasisPoints);

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    modifier correctFee(uint16 fee) {
        require(fee < BASIS_POINTS_IN_1, "Unit Protocol: INCORRECT_FEE_VALUE");
        _;
    }

    constructor(address _vaultParameters, uint16 _baseBorrowFeeBasisPoints, address _feeReceiver)
        Auth(_vaultParameters)
        nonZeroAddress(_feeReceiver)
        correctFee(_baseBorrowFeeBasisPoints)
    {
        baseBorrowFeeBasisPoints = _baseBorrowFeeBasisPoints;
        feeReceiver = _feeReceiver;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setFeeReceiver(address newFeeReceiver) external override onlyManager nonZeroAddress(newFeeReceiver) {
        feeReceiver = newFeeReceiver;

        emit FeeReceiverChanged(newFeeReceiver);
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setBaseBorrowFee(uint16 newBaseBorrowFeeBasisPoints) external override onlyManager correctFee(newBaseBorrowFeeBasisPoints) {
        baseBorrowFeeBasisPoints = newBaseBorrowFeeBasisPoints;

        emit BaseBorrowFeeChanged(newBaseBorrowFeeBasisPoints);
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function setAssetBorrowFee(address asset, bool newEnabled, uint16 newFeeBasisPoints) external override onlyManager correctFee(newFeeBasisPoints) {
        assetBorrowFee[asset].enabled = newEnabled;
        assetBorrowFee[asset].feeBasisPoints = newFeeBasisPoints;

        if (newEnabled) {
            emit AssetBorrowFeeParamsEnabled(asset, newFeeBasisPoints);
        } else {
            emit AssetBorrowFeeParamsDisabled(asset);
        }
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function getBorrowFee(address asset) public override view returns (uint16 feeBasisPoints) {
        if (assetBorrowFee[asset].enabled) {
            return assetBorrowFee[asset].feeBasisPoints;
        }

        return baseBorrowFeeBasisPoints;
    }

    /// @inheritdoc IVaultManagerBorrowFeeParameters
    function calcBorrowFeeAmount(address asset, uint usdpAmount) external override view returns (uint) {
        uint16 borrowFeeBasisPoints = getBorrowFee(asset);
        if (borrowFeeBasisPoints == 0) {
            return 0;
        }

        return usdpAmount.mul(uint(borrowFeeBasisPoints)).div(BASIS_POINTS_IN_1);
    }
}
