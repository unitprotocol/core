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
 * @dev Contract for managing the borrow fee parameters in the Unit Protocol system.
 */
contract VaultManagerBorrowFeeParameters is Auth, IVaultManagerBorrowFeeParameters {
    using SafeMath for uint;

    // Basis points in one, for fee calculations.
    uint public constant override BASIS_POINTS_IN_1 = 1e4;

    // Struct to hold asset-specific borrow fee parameters.
    struct AssetBorrowFeeParams {
        bool enabled; // Whether the custom fee for asset is enabled.
        uint16 feeBasisPoints; // Fee in basis points, where 1 basis point = 0.0001.
    }

    // Mapping from token addresses to their respective borrow fee parameters.
    mapping(address => AssetBorrowFeeParams) public assetBorrowFee;

    // The base borrow fee in basis points for all assets, unless overridden.
    uint16 public baseBorrowFeeBasisPoints;

    // Address where the collected fees are sent.
    address public override feeReceiver;

    // Event emitted when asset-specific borrow fee parameters are enabled.
    event AssetBorrowFeeParamsEnabled(address asset, uint16 feeBasisPoints);

    // Event emitted when asset-specific borrow fee parameters are disabled.
    event AssetBorrowFeeParamsDisabled(address asset);

    // Modifier to ensure the address is not zero.
    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "Unit Protocol: ZERO_ADDRESS");
        _;
    }

    // Modifier to ensure the fee is within correct range.
    modifier correctFee(uint16 fee) {
        require(fee < BASIS_POINTS_IN_1, "Unit Protocol: INCORRECT_FEE_VALUE");
        _;
    }

    /**
     * @dev Constructor for VaultManagerBorrowFeeParameters.
     * @param _vaultParameters Address of the VaultParameters contract.
     * @param _baseBorrowFeeBasisPoints The initial base borrow fee in basis points.
     * @param _feeReceiver Address where the collected fees are sent.
     */
    constructor(address _vaultParameters, uint16 _baseBorrowFeeBasisPoints, address _feeReceiver)
        Auth(_vaultParameters)
        nonZeroAddress(_feeReceiver)
        correctFee(_baseBorrowFeeBasisPoints)
    {
        baseBorrowFeeBasisPoints = _baseBorrowFeeBasisPoints;
        feeReceiver = _feeReceiver;
    }

    /**
     * @notice Sets the fee receiver address.
     * @dev Can only be called by the manager role.
     * @param newFeeReceiver The address of the new fee receiver.
     */
    function setFeeReceiver(address newFeeReceiver) external override onlyManager nonZeroAddress(newFeeReceiver) {
        feeReceiver = newFeeReceiver;
    }

    /**
     * @notice Sets the base borrow fee in basis points.
     * @dev Can only be called by the manager role.
     * @param newBaseBorrowFeeBasisPoints The new base borrow fee in basis points.
     */
    function setBaseBorrowFee(uint16 newBaseBorrowFeeBasisPoints) external override onlyManager correctFee(newBaseBorrowFeeBasisPoints) {
        baseBorrowFeeBasisPoints = newBaseBorrowFeeBasisPoints;
    }

    /**
     * @notice Sets the asset-specific borrow fee parameters.
     * @dev Can only be called by the manager role.
     * @param asset The address of the asset token.
     * @param newEnabled Whether the custom fee for the asset is enabled.
     * @param newFeeBasisPoints The fee in basis points for the asset.
     */
    function setAssetBorrowFee(address asset, bool newEnabled, uint16 newFeeBasisPoints) external override onlyManager correctFee(newFeeBasisPoints) {
        assetBorrowFee[asset].enabled = newEnabled;
        assetBorrowFee[asset].feeBasisPoints = newFeeBasisPoints;

        if (newEnabled) {
            emit AssetBorrowFeeParamsEnabled(asset, newFeeBasisPoints);
        } else {
            emit AssetBorrowFeeParamsDisabled(asset);
        }
    }

    /**
     * @notice Retrieves the borrow fee in basis points for a given asset.
     * @param asset The address of the asset token.
     * @return feeBasisPoints The fee in basis points for the asset.
     */
    function getBorrowFee(address asset) public override view returns (uint16 feeBasisPoints) {
        if (assetBorrowFee[asset].enabled) {
            return assetBorrowFee[asset].feeBasisPoints;
        }

        return baseBorrowFeeBasisPoints;
    }

    /**
     * @notice Calculates the borrow fee amount for a given asset and USDP amount.
     * @param asset The address of the asset token.
     * @param usdpAmount The amount of USDP for which to calculate the fee.
     * @return The calculated borrow fee amount.
     */
    function calcBorrowFeeAmount(address asset, uint usdpAmount) external override view returns (uint) {
        uint16 borrowFeeBasisPoints = getBorrowFee(asset);
        if (borrowFeeBasisPoints == 0) {
            return 0;
        }

        return usdpAmount.mul(uint(borrowFeeBasisPoints)).div(BASIS_POINTS_IN_1);
    }
}