// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import './BaseCDPManager.sol';

import '../interfaces/IOracleRegistry.sol';
import '../interfaces/IOracleUsd.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IVault.sol';
import '../interfaces/ICDPRegistry.sol';
import '../interfaces/vault-managers/parameters/IVaultManagerParameters.sol';
import '../interfaces/IVaultParameters.sol';
import '../interfaces/IToken.sol';

import '../helpers/ReentrancyGuard.sol';
import '../helpers/SafeMath.sol';

/**
 * @title CDPManager01
 **/
contract CDPManager01 is BaseCDPManager {
    using SafeMath for uint;

    address payable public immutable WETH;

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _cdpRegistry The address of the CDP registry
     * @param _vaultManagerBorrowFeeParameters The address of the vault manager borrow fee parameters
     **/
    constructor(address _vaultManagerParameters, address _oracleRegistry, address _cdpRegistry, address _vaultManagerBorrowFeeParameters)
        BaseCDPManager(_vaultManagerParameters, _oracleRegistry, _cdpRegistry, _vaultManagerBorrowFeeParameters)
    {
        WETH = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault()).weth();
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        require(msg.sender == WETH, "Unit Protocol: RESTRICTED");
    }

    /**
      * @notice Depositing tokens must be pre-approved to Vault address
      * @notice Borrow fee in USDP tokens must be pre-approved to CDP manager address
      * @notice position actually considered as spawned only when debt > 0
      * @dev Deposits collateral and/or borrows USDP
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join(address asset, uint assetAmount, uint usdpAmount) public nonReentrant checkpoint(asset, msg.sender) {
        require(usdpAmount != 0 || assetAmount != 0, "Unit Protocol: USELESS_TX");

        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");

        if (usdpAmount == 0) {

            vault.depositMain(asset, msg.sender, assetAmount);

        } else {

            _ensureOracle(asset);

            bool spawned = vault.debts(asset, msg.sender) != 0;

            if (!spawned) {
                // spawn a position
                vault.spawn(asset, msg.sender, oracleRegistry.oracleTypeByAsset(asset));
            }

            if (assetAmount != 0) {
                vault.depositMain(asset, msg.sender, assetAmount);
            }

            // mint USDP to owner
            vault.borrow(asset, msg.sender, usdpAmount);
            _chargeBorrowFee(asset, msg.sender, usdpAmount);

            // check collateralization
            _ensurePositionCollateralization(asset, msg.sender);

        }

        // fire an event
        emit Join(asset, msg.sender, assetAmount, usdpAmount);
    }

    /**
      * @dev Deposits ETH and/or borrows USDP
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join_Eth(uint usdpAmount) external payable {

        if (msg.value != 0) {
            IWETH(WETH).deposit{value: msg.value}();
            require(IWETH(WETH).transfer(msg.sender, msg.value), "Unit Protocol: WETH_TRANSFER_FAILED");
        }

        join(WETH, msg.value, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to withdraw
      * @param usdpAmount The amount of USDP to repay
      **/
    function exit(address asset, uint assetAmount, uint usdpAmount) public nonReentrant checkpoint(asset, msg.sender) returns (uint) {

        // check usefulness of tx
        require(assetAmount != 0 || usdpAmount != 0, "Unit Protocol: USELESS_TX");

        uint debt = vault.debts(asset, msg.sender);

        // catch full repayment
        if (usdpAmount > debt) { usdpAmount = debt; }

        if (assetAmount == 0) {
            _repay(asset, msg.sender, usdpAmount);
        } else {
            if (debt == usdpAmount) {
                vault.withdrawMain(asset, msg.sender, assetAmount);
                if (usdpAmount != 0) {
                    _repay(asset, msg.sender, usdpAmount);
                }
            } else {
                _ensureOracle(asset);

                // withdraw collateral to the owner address
                vault.withdrawMain(asset, msg.sender, assetAmount);

                if (usdpAmount != 0) {
                    _repay(asset, msg.sender, usdpAmount);
                }

                vault.update(asset, msg.sender);

                _ensurePositionCollateralization(asset, msg.sender);
            }
        }

        // fire an event
        emit Exit(asset, msg.sender, assetAmount, usdpAmount);

        return usdpAmount;
    }

    /**
      * @notice Repayment is the sum of the principal and interest
      * @dev Withdraws collateral and repays specified amount of debt
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to withdraw
      * @param repayment The target repayment amount
      **/
    function exit_targetRepayment(address asset, uint assetAmount, uint repayment) external returns (uint) {

        uint usdpAmount = _calcPrincipal(asset, msg.sender, repayment);

        return exit(asset, assetAmount, usdpAmount);
    }

    /**
      * @notice Withdraws WETH and converts to ETH
      * @param ethAmount ETH amount to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function exit_Eth(uint ethAmount, uint usdpAmount) public returns (uint) {
        usdpAmount = exit(WETH, ethAmount, usdpAmount);
        require(IWETH(WETH).transferFrom(msg.sender, address(this), ethAmount), "Unit Protocol: WETH_TRANSFER_FROM_FAILED");
        IWETH(WETH).withdraw(ethAmount);
        (bool success, ) = msg.sender.call{value:ethAmount}("");
        require(success, "Unit Protocol: ETH_TRANSFER_FAILED");
        return usdpAmount;
    }

    /**
      * @notice Repayment is the sum of the principal and interest
      * @notice Withdraws WETH and converts to ETH
      * @param ethAmount ETH amount to withdraw
      * @param repayment The target repayment amount
      **/
    function exit_Eth_targetRepayment(uint ethAmount, uint repayment) external returns (uint) {
        uint usdpAmount = _calcPrincipal(WETH, msg.sender, repayment);
        return exit_Eth(ethAmount, usdpAmount);
    }

    function _ensurePositionCollateralization(address asset, address owner) internal view {
        // collateral value of the position in USD
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        // USD limit of the position
        uint usdLimit = usdValue_q112 * vaultManagerParameters.initialCollateralRatio(asset) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, owner) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }

    // Liquidation Trigger

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the collateral token of a position
     * @param owner The owner of the position
     **/
    function triggerLiquidation(address asset, address owner) external nonReentrant {

        _ensureOracle(asset);

        // USD value of the collateral
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        // reverts if a position is not liquidatable
        require(_isLiquidatablePosition(asset, owner, usdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = usdValue_q112.mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = usdValue_q112.sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, owner, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, owner);
    }

    function getCollateralUsdValue_q112(address asset, address owner) public view returns (uint) {
        return IOracleUsd(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, owner));
    }

    function _ensureOracle(address asset) internal view {
        uint oracleType = oracleRegistry.oracleTypeByAsset(asset);
        require(oracleType != 0, "Unit Protocol: INVALID_ORACLE_TYPE");
        address oracle = oracleRegistry.oracleByType(oracleType);
        require(oracle != address(0), "Unit Protocol: DISABLED_ORACLE");
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address owner
    ) public view returns (bool) {
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        return _isLiquidatablePosition(asset, owner, usdValue_q112);
    }

    /**
     * @dev Calculates current utilization ratio
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return utilization ratio
     **/
    function utilizationRatio(
        address asset,
        address owner
    ) public view returns (uint) {
        uint debt = vault.getTotalDebt(asset, owner);
        if (debt == 0) return 0;

        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        return debt.mul(100).mul(Q112).div(usdValue_q112);
    }
}
