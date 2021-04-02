// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import '../interfaces/IOracleRegistry.sol';
import '../interfaces/IOracleUsd.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IVault.sol';
import '../interfaces/ICDPRegistry.sol';
import '../interfaces/IVaultManagerParameters.sol';
import '../interfaces/IVaultParameters.sol';

import '../helpers/ReentrancyGuard.sol';
import '../helpers/SafeMath.sol';

interface IToken {
    function decimals() external view returns (uint8);
}

interface ICurveProvider {
    function get_registry() external view returns (address);
}

interface ICurveRegistry {
    function get_pool_from_lp_token(address) external view returns (address);
}

interface IWrappedToUnderlyingOracle {
    function assetToUnderlying(address) external view returns (address);
}

/**
 * @title CDPManager01
 **/
contract CDPManager01 is ReentrancyGuard {
    using SafeMath for uint;

    IVault public immutable vault;
    IVaultManagerParameters public immutable vaultManagerParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICDPRegistry public immutable cdpRegistry;
    address payable public immutable WETH;
    
    // CurveProvider contract
    ICurveProvider public immutable curveProvider;

    uint public constant Q112 = 2 ** 112;
    uint public constant DENOMINATOR_1E5 = 1e5;
    uint public constant DENOMINATOR_1E2 = 1e2;
    uint public constant WRAPPED_TO_UNDERLYING_ORACLE_TYPE = 11;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed user, uint main, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed user, uint main, uint usdp);

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed token, address indexed user);

    /**
     * @dev Trigger when buyouts are happened
    **/
    event Buyout(address indexed asset, address indexed owner, address indexed buyer, uint amount, uint price, uint penalty);

    modifier checkpoint(address asset, address owner) {
        _;
        cdpRegistry.checkpoint(asset, owner);
    }

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _curveProvider The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383
     * @param _cdpRegistry The address of the CDP registry
     **/
    constructor(address _vaultManagerParameters, address _oracleRegistry, address _curveProvider, address _cdpRegistry) {
        require(
            _vaultManagerParameters != address(0) && 
            _oracleRegistry != address(0) && 
            _cdpRegistry != address(0) &&
            _curveProvider != address(0), 
                "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        vault = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        WETH = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault()).weth();
        curveProvider = ICurveProvider(_curveProvider);
        cdpRegistry = ICDPRegistry(_cdpRegistry);
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        require(msg.sender == WETH, "Unit Protocol: RESTRICTED");
    }

    /**
      * @notice Depositing tokens must be pre-approved to Vault address
      * @notice position actually considered as spawned only when debt > 0
      * @dev Deposits collateral and/or borrows USDP
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join(address asset, uint assetAmount, uint usdpAmount) public nonReentrant checkpoint(asset, msg.sender) {
        require(usdpAmount != 0 || assetAmount != 0, "Unit Protocol: USELESS_TX");

        if (usdpAmount == 0) {

            vault.depositMain(asset, msg.sender, assetAmount);

        } else {

            // check oracle
            address oracle = oracleRegistry.oracleByAsset(asset);
            require(oracle != address(0), "Unit Protocol: DISABLED_ORACLE");

            bool spawned = vault.getTotalDebt(asset, msg.sender) != 0;

            if (!spawned) {
                // spawn a position
                vault.spawn(asset, msg.sender, oracleRegistry.oracleTypeByOracle(oracle));
            }

            if (assetAmount != 0) {
                vault.depositMain(asset, msg.sender, assetAmount);
            }

            // mint USDP to user
            vault.borrow(asset, msg.sender, usdpAmount);

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
            IWETH(WETH).transfer(msg.sender, msg.value);
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
            if (debt == 0 || debt == usdpAmount) {
                vault.withdrawMain(asset, msg.sender, assetAmount);
                _repay(asset, msg.sender, usdpAmount);
            } else {
                // check oracle
                require(oracleRegistry.oracleByAsset(asset) != address(0), "Unit Protocol: DISABLED_ORACLE");

                // withdraw collateral to the user address
                vault.withdrawMain(asset, msg.sender, assetAmount);

                if (usdpAmount != 0) {
                    uint fee = vault.calculateFee(asset, msg.sender, usdpAmount);
                    vault.chargeFee(vault.usdp(), msg.sender, fee);
                    vault.repay(asset, msg.sender, usdpAmount);
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
      * @notice Exists with ETH
      * @param ethAmount ETH amount to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function exit_Eth(uint ethAmount, uint usdpAmount) external {
        exit(WETH, ethAmount, usdpAmount);
        IWETH(WETH).transferFrom(msg.sender, address(this), ethAmount);
        IWETH(WETH).withdraw(ethAmount);
        (bool success, ) = msg.sender.call{value:ethAmount}("");
        require(success, "Unit Protocol: ETH_TRANSFER_FAILED");
    }

    // decreases debt
    function _repay(address asset, address user, uint usdpAmount) internal {
        uint fee = vault.calculateFee(asset, user, usdpAmount);
        vault.chargeFee(vault.usdp(), user, fee);

        // burn USDP from the user's balance
        uint debtAfter = vault.repay(asset, user, usdpAmount);
        if (debtAfter == 0) {
            // clear unused storage
            vault.destroy(asset, user);
        }
    }

    function _ensurePositionCollateralization(address asset, address user) internal view {
        // collateral value of the position in USD
        uint usdValue_q112 = IOracleUsd(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));

        // USD limit of the position
        uint usdLimit = usdValue_q112 * vaultManagerParameters.initialCollateralRatio(asset) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, user) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }
    
    // Liquidation Trigger

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the collateral token of a position
     * @param user The owner of the position
     **/
    function triggerLiquidation(address asset, address user) external nonReentrant {

        // check oracle
        require(oracleRegistry.oracleByAsset(asset) != address(0), "Unit Protocol: DISABLED_ORACLE");

        // USD value of the collateral
        uint usdValue_q112 = IOracleUsd(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));
        
        // reverts if a position is not liquidatable
        require(_isLiquidatablePosition(asset, user, usdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = usdValue_q112.mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = usdValue_q112.sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, user, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, user);
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param user The owner of the position
     * @param usdValue_q112 Q112-encoded USD value of the collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function _isLiquidatablePosition(
        address asset,
        address user,
        uint usdValue_q112
    ) internal view returns (bool) {
        uint debt = vault.getTotalDebt(asset, user);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        return debt.mul(100).mul(Q112).div(usdValue_q112) >= vaultManagerParameters.liquidationRatio(asset);
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param user The owner of the position
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user
    ) external view returns (bool) {
        return utilizationRatio(asset, user) >= vaultManagerParameters.liquidationRatio(asset);
    }

    /**
     * @dev Calculates current utilization ratio
     * @param asset The address of the collateral
     * @param user The owner of the position
     * @return utilization ratio
     **/
    function utilizationRatio(
        address asset,
        address user
    ) public view returns (uint) {
        uint debt = vault.getTotalDebt(asset, user);
        if (debt == 0) return uint(-1);
        
        uint usdValue_q112 = IOracleUsd(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));

        return debt.mul(100).mul(Q112).div(usdValue_q112);
    }
    

    /**
     * @dev Calculates liquidation price
     * @param asset The address of the collateral
     * @param user The owner of the position
     * @return Q112-encoded liquidation price
     **/
    function liquidationPrice_q112(
        address asset,
        address user
    ) external view returns (uint) {
        uint debt = vault.getTotalDebt(asset, user);
        if (debt == 0) return uint(-1);
        
        uint collateralLiqPrice = debt.mul(100).mul(Q112).div(vaultManagerParameters.liquidationRatio(asset));
        
        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");
        
        return collateralLiqPrice / vault.collaterals(asset, user) / 10 ** (18 - IToken(asset).decimals());
        
    }

    /**
     * @dev Buyouts a position's collateral
     * @param asset The address of the main collateral token of a position
     * @param owner The owner of a position
     **/
    function buyout(address asset, address owner) public nonReentrant checkpoint(asset, owner) {
        require(vault.liquidationBlock(asset, owner) != 0, "Unit Protocol: LIQUIDATION_NOT_TRIGGERED");
        uint startingPrice = vault.liquidationPrice(asset, owner);
        uint blocksPast = block.number.sub(vault.liquidationBlock(asset, owner));
        uint depreciationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, owner);
        uint penalty = debt.mul(vault.liquidationFee(asset, owner)).div(DENOMINATOR_1E2);
        uint collateralInPosition = vault.collaterals(asset, owner);

        uint collateralToLiquidator;
        uint collateralToOwner;
        uint repayment;

        (collateralToLiquidator, collateralToOwner, repayment) = _calcLiquidationParams(
            depreciationPeriod,
            blocksPast,
            startingPrice,
            debt.add(penalty),
            collateralInPosition
        );

        // ensure that at least 1 wei of Curve LP is transferred to cdp owner
        if (collateralToOwner == 0 && isCurveLP(asset)) {
            collateralToOwner = 1;
            collateralToLiquidator = collateralToLiquidator.sub(1);
        }

        _liquidate(
            asset,
            owner,
            collateralToLiquidator,
            collateralToOwner,
            repayment,
            penalty
        );
    }

    function _liquidate(
        address asset,
        address user,
        uint collateralToBuyer,
        uint collateralToOwner,
        uint repayment,
        uint penalty
    ) private {
        // send liquidation command to the Vault
        vault.liquidate(
            asset,
            user,
            collateralToBuyer,
            0, // colToLiquidator
            collateralToOwner,
            0, // colToPositionOwner
            repayment,
            penalty,
            msg.sender
        );
        // fire an buyout event
        emit Buyout(asset, user, msg.sender, collateralToBuyer, repayment, penalty);
    }

    function _calcLiquidationParams(
        uint depreciationPeriod,
        uint blocksPast,
        uint startingPrice,
        uint debtWithPenalty,
        uint collateralInPosition
    )
    internal
    pure
    returns(
        uint collateralToBuyer,
        uint collateralToOwner,
        uint price
    ) {
        if (depreciationPeriod > blocksPast) {
            uint valuation = depreciationPeriod.sub(blocksPast);
            uint collateralPrice = startingPrice.mul(valuation).div(depreciationPeriod);
            if (collateralPrice > debtWithPenalty) {
                collateralToBuyer = collateralInPosition.mul(debtWithPenalty).div(collateralPrice);
                collateralToOwner = collateralInPosition.sub(collateralToBuyer);
                price = debtWithPenalty;
            } else {
                collateralToBuyer = collateralInPosition;
                price = collateralPrice;
            }
        } else {
            collateralToBuyer = collateralInPosition;
        }
    }

    function isCurveLP(address asset) public view returns(bool) {
        address underlying = IWrappedToUnderlyingOracle(oracleRegistry.oracleByType(WRAPPED_TO_UNDERLYING_ORACLE_TYPE)).assetToUnderlying(asset);

        if (underlying == address(0)) { return false; }

        return ICurveRegistry(curveProvider.get_registry()).get_pool_from_lp_token(underlying) != address(0);
    }
}
