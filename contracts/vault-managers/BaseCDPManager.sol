// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IVault.sol";
import '../interfaces/IVaultParameters.sol';
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/ICDPRegistry.sol";
import '../interfaces/IToken.sol';
import "../interfaces/vault-managers/parameters/IVaultManagerParameters.sol";
import "../interfaces/vault-managers/parameters/IVaultManagerBorrowFeeParameters.sol";

import "../helpers/ReentrancyGuard.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


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
    IERC20 public immutable usdp;

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
        IVault vaultLocal = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        vault = vaultLocal;
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        cdpRegistry = ICDPRegistry(_cdpRegistry);
        vaultManagerBorrowFeeParameters = IVaultManagerBorrowFeeParameters(_vaultManagerBorrowFeeParameters);
        usdp = IERC20(vaultLocal.usdp());
    }

    /**
     * @notice Charge borrow fee if needed
     */
    function _chargeBorrowFee(address asset, address user, uint usdpAmount) internal {
        uint borrowFee = vaultManagerBorrowFeeParameters.calcBorrowFeeAmount(asset, usdpAmount);
        if (borrowFee == 0) { // very small amount case
            return;
        }

        // to fail with concrete reason, not with TRANSFER_FROM_FAILED from safeTransferFrom
        require(usdp.allowance(user, address(this)) >= borrowFee, "Unit Protocol: BORROW_FEE_NOT_APPROVED");

        TransferHelper.safeTransferFrom(
            address(usdp),
            user,
            vaultManagerBorrowFeeParameters.feeReceiver(),
            borrowFee
        );
    }

    // decreases debt
    function _repay(address asset, address owner, uint usdpAmount) internal {
        uint fee = vault.calculateFee(asset, owner, usdpAmount);
        vault.chargeFee(vault.usdp(), owner, fee);

        // burn USDP from the owner's balance
        uint debtAfter = vault.repay(asset, owner, usdpAmount);
        if (debtAfter == 0) {
            // clear unused storage
            vault.destroy(asset, owner);
        }
    }

    /**
     * @dev Calculates liquidation price
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return Q112-encoded liquidation price
     **/
    function liquidationPrice_q112(
        address asset,
        address owner
    ) external view returns (uint) {
        uint debt = vault.getTotalDebt(asset, owner);
        if (debt == 0) return uint(-1);

        uint collateralLiqPrice = debt.mul(100).mul(Q112).div(vaultManagerParameters.liquidationRatio(asset));

        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");

        return collateralLiqPrice / vault.collaterals(asset, owner) / 10 ** (18 - IToken(asset).decimals());
    }

    function _calcPrincipal(address asset, address owner, uint repayment) internal view returns (uint) {
        uint fee = vault.stabilityFee(asset, owner) * (block.timestamp - vault.lastUpdate(asset, owner)) / 365 days;
        return repayment * DENOMINATOR_1E5 / (DENOMINATOR_1E5 + fee);
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @param usdValue_q112 Q112-encoded USD value of the collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function _isLiquidatablePosition(
        address asset,
        address owner,
        uint usdValue_q112
    ) internal view returns (bool) {
        uint debt = vault.getTotalDebt(asset, owner);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        return debt.mul(100).mul(Q112).div(usdValue_q112) >= vaultManagerParameters.liquidationRatio(asset);
    }
}
