// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

interface OracleSimple {
    function assetToUsd(address asset, uint amount) external view returns (uint);
}

interface OracleRegistry {
    function oracleByAsset(address) external view returns (address);
    function oracleByType(uint) external view returns (address);
}


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IVault {
    function spawn(address, address, uint) external;
    function depositMain(address, address, uint) external;
    function borrow(address, address, uint) external;
    function withdrawMain(address, address, uint) external;
    function chargeFee(address, address, uint) external;
    function repay(address, address, uint) external;
    function update(address, address) external;
    function triggerLiquidation(address, address, uint) external;
    
    function liquidate(address, address, uint, uint, uint, uint, uint, uint, address) external;

    function getTotalDebt(address, address) external view returns (uint);
    function weth() external view returns (address payable);
    function usdp() external view returns (address);
    function debts(address, address) external view returns (uint);
    function collaterals(address, address) external view returns (uint);
    function calculateFee(address, address, uint) external view returns (uint);
    function liquidationFee(address, address) external view returns (uint);
    
    function liquidationBlock(address, address) external view returns (uint);
    function liquidationPrice(address, address) external view returns (uint);
}

interface IVaultManagerParameters {
    function vaultParameters() external view returns (address);
    function initialCollateralRatio(address) external view returns (uint);
    function liquidationRatio(address) external view returns (uint);
    function liquidationDiscount(address) external view returns (uint);
    function devaluationPeriod(address) external view returns (uint);
}

interface IVaultParameters {
    function vault() external view returns (address);
}

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
    OracleRegistry public immutable oracleRegistry;
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

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _curveProvider The address of the Curve Provider. Mainnet: 0x0000000022D53366457F9d5E68Ec105046FC4383
     **/
    constructor(address _vaultManagerParameters, address _oracleRegistry, address _curveProvider) {
        require(
            _vaultManagerParameters != address(0) && 
            _oracleRegistry != address(0) &&
            _curveProvider != address(0), 
                "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        vault = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        oracleRegistry = OracleRegistry(_oracleRegistry);
        WETH = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault()).weth();
        curveProvider = ICurveProvider(_curveProvider);
    }

    /**
      * @notice Depositing tokens must be pre-approved to Vault address
      * @notice position actually considered as spawned only when debt > 0
      * @dev Deposits collateral and/or borrows USDP
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join(address asset, uint assetAmount, uint usdpAmount) public nonReentrant {
        require(usdpAmount != 0 || assetAmount != 0, "Unit Protocol: USELESS_TX");

        if (usdpAmount == 0) {

            vault.depositMain(asset, msg.sender, assetAmount);

        } else {

            bool spawned = vault.getTotalDebt(asset, msg.sender) != 0;

            // check oracle
            require(oracleRegistry.oracleByAsset(asset) != address(0), "Unit Protocol: DISABLED_ORACLE");

            if (!spawned) {
                // spawn a position
                vault.spawn(asset, msg.sender, 0);
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
    function exit(address asset, uint assetAmount, uint usdpAmount) public nonReentrant {

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
        uint usdValue_q112 = OracleSimple(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));

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
        uint usdValue_q112 = OracleSimple(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));
        
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
        
        uint usdValue_q112 = OracleSimple(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, user));

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
     * @param user The owner of a position
     **/
    function buyout(address asset, address user) public nonReentrant {
        require(vault.liquidationBlock(asset, user) != 0, "Unit Protocol: LIQUIDATION_NOT_TRIGGERED");
        uint startingPrice = vault.liquidationPrice(asset, user);
        uint blocksPast = block.number.sub(vault.liquidationBlock(asset, user));
        uint depreciationPeriod = vaultManagerParameters.devaluationPeriod(asset);
        uint debt = vault.getTotalDebt(asset, user);
        uint penalty = debt.mul(vault.liquidationFee(asset, user)).div(DENOMINATOR_1E2);
        uint collateralInPosition = vault.collaterals(asset, user);

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
            user,
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
