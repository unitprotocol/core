// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IVault.sol";
import "../interfaces/IVaultManagerParameters.sol";
import '../interfaces/IVaultParameters.sol';
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/ICDPRegistry.sol";
import "../interfaces/parameters/IVaultManagerBorrowFeeParameters.sol";

import "../helpers/ReentrancyGuard.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/SafeMath.sol";

import "../USDP.sol";


/**
 * @title BaseCDPManager
 * @dev all common logic should be moved here in future
 **/
abstract contract BaseCDPManager is ReentrancyGuard {
    using SafeMath for uint;

    IVault public immutable vault;
    IVaultManagerParameters public immutable vaultManagerParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICDPRegistry public immutable cdpRegistry;
    IVaultManagerBorrowFeeParameters public immutable vaultManagerBorrowFeeParameters;

    uint public constant Q112 = 2 ** 112;
    uint public constant DENOMINATOR_1E5 = 1e5;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed asset, address indexed owner);

    modifier checkpoint(address asset, address owner) {
        _;
        cdpRegistry.checkpoint(asset, owner);
    }

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _cdpRegistry The address of the CDP registry
     * @param _vaultManagerBorrowFeeParameters The address of the vault manager borrow fee parameters
     **/
    constructor(address _vaultManagerParameters, address _oracleRegistry, address _cdpRegistry, address _vaultManagerBorrowFeeParameters) {
        require(
            _vaultManagerParameters != address(0) &&
            _oracleRegistry != address(0) &&
            _cdpRegistry != address(0) &&
            _vaultManagerBorrowFeeParameters != address(0),
            "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        vault = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        cdpRegistry = ICDPRegistry(_cdpRegistry);
        vaultManagerBorrowFeeParameters = IVaultManagerBorrowFeeParameters(_vaultManagerBorrowFeeParameters);
    }

    /**
     * @notice Charge borrow fee if needed
     */
    function _chargeBorrowFee(address asset, uint usdpAmount) internal {
        uint32 borrowFeePercent = vaultManagerBorrowFeeParameters.getBorrowFee(asset);
        if (borrowFeePercent == 0) {
            return;
        }

        uint borrowFee = usdpAmount.mul(uint(borrowFeePercent)).div(uint(vaultManagerBorrowFeeParameters.BORROW_FEE_100_PERCENT()));
        if (borrowFee == 0) { // very small amount case
            return;
        }

        // to fail with concrete reason, not with TRANSFER_FROM_FAILED from safeTransferFrom
        require(USDP(vault.usdp()).allowance(msg.sender, address(this)) >= borrowFee, "Unit Protocol: BORROW_FEE_NOT_APPROVED");

        TransferHelper.safeTransferFrom(
            vault.usdp(),
            msg.sender,
            vaultManagerBorrowFeeParameters.feeReceiver(),
            borrowFee
        );
    }
}
