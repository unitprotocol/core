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
import "../interfaces/swappers/ISwappersRegistry.sol";

import "../helpers/ReentrancyGuard.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title BaseCDPManager
 * @notice Abstract contract for Collateralized Debt Position (CDP) management in Unit Protocol.
 * @dev Contains common logic for CDP management, with future scope for extension.
 */
abstract contract BaseCDPManager is ReentrancyGuard {
    using SafeMath for uint;

    IVault public immutable vault;
    IVaultParameters public immutable vaultParameters;
    IVaultManagerParameters public immutable vaultManagerParameters;
    IVaultManagerBorrowFeeParameters public immutable vaultManagerBorrowFeeParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICDPRegistry public immutable cdpRegistry;
    ISwappersRegistry public immutable swappersRegistry;
    IERC20 public immutable usdp;

    uint public constant Q112 = 2 ** 112;
    uint public constant DENOMINATOR_1E5 = 1e5;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Log joins with leverage
     **/
    event JoinWithLeverage(address indexed asset, address indexed owner, uint userAssetAmount, uint swappedAssetAmount, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Log exit with deleverage
     **/
    event ExitWithDeleverage(address indexed asset, address indexed owner, uint assetToUser, uint assetToSwap, uint usdp);

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed asset, address indexed owner);

    modifier checkpoint(address asset, address owner) {
        _;
        cdpRegistry.checkpoint(asset, owner);
    }

    /**
     * @notice Constructs the BaseCDPManager contract.
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _vaultManagerBorrowFeeParameters The address of the vault manager borrow fee parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _cdpRegistry The address of the CDP registry
     * @param _swappersRegistry The address of the swappers registry
     */
    constructor(
        address _vaultManagerParameters,
        address _vaultManagerBorrowFeeParameters,
        address _oracleRegistry,
        address _cdpRegistry,
        address _swappersRegistry
    ) {
        require(
            _vaultManagerParameters != address(0) &&
            _oracleRegistry != address(0) &&
            _cdpRegistry != address(0) &&
            _vaultManagerBorrowFeeParameters != address(0) &&
            _swappersRegistry != address(0)
            , "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        IVault vaultLocal = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        vault = vaultLocal;
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        cdpRegistry = ICDPRegistry(_cdpRegistry);
        swappersRegistry = ISwappersRegistry(_swappersRegistry);
        vaultManagerBorrowFeeParameters = IVaultManagerBorrowFeeParameters(_vaultManagerBorrowFeeParameters);
        usdp = IERC20(vaultLocal.usdp());
        vaultParameters = IVaultParameters(vaultLocal.vaultParameters());
    }

    /**
     * @notice Charges a borrow fee if needed when borrowing USDP against collateral.
     * @param asset The address of the collateral asset.
     * @param user The address of the user borrowing USDP.
     * @param usdpAmount The amount of USDP being borrowed.
     * @return borrowFee The calculated borrow fee.
     * @dev Throws an error if the USDP allowance for the fee is not approved by the user.
     */
    function _chargeBorrowFee(address asset, address user, uint usdpAmount) internal returns (uint borrowFee) {
        borrowFee = vaultManagerBorrowFeeParameters.calcBorrowFeeAmount(asset, usdpAmount);
        if (borrowFee == 0) { // very small amount case
            return borrowFee;
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

    /**
     * @notice Repays a portion of the debt in USDP.
     * @param asset The address of the collateral asset.
     * @param owner The owner of the debt.
     * @param usdpAmount The amount of USDP to repay.
     * @dev Destroys the CDP if the debt after repayment is zero.
     */
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
     * @notice Calculates the liquidation price for a given collateral and owner.
     * @param asset The address of the collateral.
     * @param owner The owner of the position.
     * @return The liquidation price, Q112-encoded.
     */
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

    /**
     * @notice Calculates the principal amount for a given repayment.
     * @param asset The address of the collateral asset.
     * @param owner The owner of the debt.
     * @param repayment The total repayment amount.
     * @return The principal amount of the repayment.
     */
    function _calcPrincipal(address asset, address owner, uint repayment) internal view returns (uint) {
        uint multiplier = repayment;
        uint fee = vault.calculateFee(asset, owner, multiplier);

        return repayment * multiplier / (multiplier + fee);
        /*
            x + fee(x) = repayment
            x + x * feePercent * pastTime / 365 days / denominator = repayment
            x * (1 + feePercent * pastTime / 365 days / denominator) = repayment
            x * (1 + fee(1)) = repayment
            x = repayment / (1 + fee(1))
            With usage in such way we have huge rounding error on small pastTime
            Will multipy numerator and denominator of right part with big enough number. Repayment is good enough for this purposes
        */
    }

    /**
     * @notice Determines whether a position is liquidatable.
     * @param asset The address of the collateral.
     * @param owner The owner of the position.
     * @param usdValue_q112 Q112-encoded USD value of the collateral.
     * @return A boolean indicating whether the position is liquidatable.
     */
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

    /**
     * @notice Ensures the existence of an oracle for a given asset.
     * @param asset The address of the asset.
     * @return oracleType The type of the oracle.
     * @dev Throws an error if the oracle type is invalid or the oracle is disabled.
     */
    function _ensureOracle(address asset) internal view virtual returns (uint oracleType) {
        oracleType = oracleRegistry.oracleTypeByAsset(asset);
        require(oracleType != 0, "Unit Protocol: INVALID_ORACLE_TYPE");

        address oracle = oracleRegistry.oracleByType(oracleType);
        require(oracle != address(0), "Unit Protocol: DISABLED_ORACLE");
    }

    /**
     * @notice Mints USDP against the provided collateral.
     * @param _asset The address of the collateral asset.
     * @param _owner The owner of the collateral.
     * @param _amount The amount of USDP to mint.
     * @return usdpAmountToUser The net amount of USDP provided to the user after fees.
     */
    function _mintUsdp(address _asset, address _owner, uint _amount) internal returns (uint usdpAmountToUser) {
        uint oracleType = _ensureOracle(_asset);

        bool spawned = vault.debts(_asset, _owner) != 0;
        if (spawned) {
            require(vault.oracleType(_asset, _owner) == oracleType, "Unit Protocol: INCONSISTENT_USER_ORACLE_TYPE");
        } else {
            vault.spawn(_asset, _owner, oracleType);
        }

        vault.borrow(_asset, _owner, _amount);
        uint borrowFee = _chargeBorrowFee(_asset, _owner, _amount);

        return _amount.sub(borrowFee);
    }

    /**
     * @notice Swaps USDP to a specified asset and performs checks on the swapped amount.
     * @param swapper The ISwapper interface to perform the swap.
     * @param _asset The address of the asset to swap to.
     * @param _usdpAmountToSwap The amount of USDP to swap.
     * @param _minSwappedAssetAmount The minimum acceptable amount of the asset to receive from the swap.
     * @return swappedAssetAmount The actual amount of the asset received from the swap.
     * @dev Verifies that the swapped amount is at least the minimum specified and the balance changes are as expected.
     *      Throws an error if the swapped amount is less than the minimum or if the balance changes are not as expected.
     */
    function _swapUsdpToAssetAndCheck(ISwapper swapper, address _asset, uint _usdpAmountToSwap, uint _minSwappedAssetAmount) internal returns(uint swappedAssetAmount) {
        uint assetBalanceBeforeSwap = IERC20(_asset).balanceOf(msg.sender);
        uint usdpBalanceBeforeSwap = usdp.balanceOf(msg.sender);

        swappedAssetAmount = swapper.swapUsdpToAsset(msg.sender, _asset, _usdpAmountToSwap, _minSwappedAssetAmount);

        require(swappedAssetAmount >= _minSwappedAssetAmount, "Unit Protocol: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
        require(IERC20(_asset).balanceOf(msg.sender) == assetBalanceBeforeSwap.add(swappedAssetAmount), "Unit Protocol: INVALID_SWAPPED_ASSET_AMOUNT_RETURNED");
        require(usdp.balanceOf(msg.sender) == usdpBalanceBeforeSwap.sub(_usdpAmountToSwap), "Unit Protocol: INVALID_USDP_AMOUNT_GOT_FOR_SWAP_BY_SWAPPER");
    }

    /**
     * @notice Swaps a specified asset to USDP and performs checks on the swapped amount.
     * @param swapper The ISwapper interface to perform the swap.
     * @param _asset The address of the asset to swap.
     * @param _assetAmountToSwap The amount of the asset to swap.
     * @param _minSwappedUsdpAmount The minimum acceptable amount of USDP to receive from the swap.
     * @return swappedUsdpAmount The actual amount of USDP received from the swap.
     * @dev Verifies that the swapped amount is at least the minimum specified and the balance changes are as expected.
     *      Throws an error if the swapped amount is less than the minimum or if the balance changes are not as expected.
     */
    function _swapAssetToUsdpAndCheck(ISwapper swapper, address _asset, uint _assetAmountToSwap, uint _minSwappedUsdpAmount) internal returns(uint swappedUsdpAmount) {
        uint assetBalanceBeforeSwap = IERC20(_asset).balanceOf(msg.sender);
        uint usdpBalanceBeforeSwap = usdp.balanceOf(msg.sender);

        swappedUsdpAmount = swapper.swapAssetToUsdp(msg.sender, _asset, _assetAmountToSwap, _minSwappedUsdpAmount);

        require(swappedUsdpAmount >= _minSwappedUsdpAmount, "Unit Protocol: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
        require(IERC20(_asset).balanceOf(msg.sender) == assetBalanceBeforeSwap.sub(_assetAmountToSwap), "Unit Protocol: INVALID_ASSET_AMOUNT_GOT_FOR_SWAP_BY_SWAPPER");
        require(usdp.balanceOf(msg.sender) == usdpBalanceBeforeSwap.add(swappedUsdpAmount), "Unit Protocol: INVALID_SWAPPED_USDP_AMOUNT_RETURNED");
    }
}
