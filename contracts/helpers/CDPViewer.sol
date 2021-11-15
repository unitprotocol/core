// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

pragma experimental ABIEncoderV2;

import "../interfaces/IVault.sol";
import "../interfaces/IVaultParameters.sol";
import "../interfaces/vault-managers/parameters/IVaultManagerParameters.sol";
import "../interfaces/vault-managers/parameters/IVaultManagerBorrowFeeParameters.sol";
import "../interfaces/IOracleRegistry.sol";
import "./IUniswapV2PairFull.sol";
import "./ERC20Like.sol";


/**
 * @notice Views collaterals in one request to save node requests and speed up dapps.
 */
contract CDPViewer {

    IVault public immutable vault;
    IVaultParameters public immutable vaultParameters;
    IVaultManagerParameters public immutable vaultManagerParameters;
    IVaultManagerBorrowFeeParameters public immutable vaultManagerBorrowFeeParameters;
    IOracleRegistry public immutable oracleRegistry;

    struct CDP {

        // Collateral amount
        uint128 collateral;

        // Debt amount
        uint128 debt;

        // Debt + accrued stability fee
        uint totalDebt;

        // Percentage with 3 decimals
        uint32 stabilityFee;

        uint32 lastUpdate;

        // Percentage with 0 decimals
        uint16 liquidationFee;

        uint16 oracleType;
    }

    struct CollateralParameters {

        // USDP mint limit
        uint128 tokenDebtLimit;

        // USDP mint limit
        uint128 tokenDebt;

        // Percentage with 3 decimals
        uint32 stabilityFee;

        // Percentage with 3 decimals
        uint32 liquidationDiscount;

        // Devaluation period in blocks
        uint32 devaluationPeriod;

        // Percentage with 0 decimals
        uint16 liquidationRatio;

        // Percentage with 0 decimals
        uint16 initialCollateralRatio;

        // Percentage with 0 decimals
        uint16 liquidationFee;

        // Oracle types enabled for this asset
        uint16 oracleType;

        // Percentage with 2 decimals (basis points)
        uint16 borrowFee;

        CDP cdp;
    }

    struct TokenDetails {
        address[2] lpUnderlyings;
        uint128 balance;
        uint128 totalSupply;
    }


    constructor(address _vaultManagerParameters, address _oracleRegistry, address _vaultManagerBorrowFeeParameters) {
         IVaultManagerParameters vmp = IVaultManagerParameters(_vaultManagerParameters);
         vaultManagerParameters = vmp;
         IVaultParameters vp = IVaultParameters(vmp.vaultParameters());
         vaultParameters = vp;
         vault = IVault(vp.vault());
         oracleRegistry = IOracleRegistry(_oracleRegistry);
         vaultManagerBorrowFeeParameters = IVaultManagerBorrowFeeParameters(_vaultManagerBorrowFeeParameters);
    }

    /**
     * @notice Get parameters of one asset
     * @param asset asset address
     * @param owner owner address
     */
    function getCollateralParameters(address asset, address owner)
        public
        view
        returns (CollateralParameters memory r)
    {
        r.stabilityFee = uint32(vaultParameters.stabilityFee(asset));
        r.liquidationFee = uint16(vaultParameters.liquidationFee(asset));
        r.initialCollateralRatio = uint16(vaultManagerParameters.initialCollateralRatio(asset));
        r.liquidationRatio = uint16(vaultManagerParameters.liquidationRatio(asset));
        r.liquidationDiscount = uint32(vaultManagerParameters.liquidationDiscount(asset));
        r.devaluationPeriod = uint32(vaultManagerParameters.devaluationPeriod(asset));

        r.tokenDebtLimit = uint128(vaultParameters.tokenDebtLimit(asset));
        r.tokenDebt = uint128(vault.tokenDebts(asset));
        r.oracleType = uint16(oracleRegistry.oracleTypeByAsset(asset));

        r.borrowFee = vaultManagerBorrowFeeParameters.getBorrowFee(asset);

        if (owner == address(0)) return r;
        r.cdp.stabilityFee = uint32(vault.stabilityFee(asset, owner));
        r.cdp.liquidationFee = uint16(vault.liquidationFee(asset, owner));
        r.cdp.debt = uint128(vault.debts(asset, owner));
        r.cdp.totalDebt = vault.getTotalDebt(asset, owner);
        r.cdp.collateral = uint128(vault.collaterals(asset, owner));
        r.cdp.lastUpdate = uint32(vault.lastUpdate(asset, owner));
        r.cdp.oracleType = uint16(vault.oracleType(asset, owner));
    }

    /**
     * @notice Get details of one token
     * @param asset token address
     * @param owner owner address
     */
    function getTokenDetails(address asset, address owner)
        public
        view
        returns (TokenDetails memory r)
    {
        try IUniswapV2PairFull(asset).token0() returns(address token0) {
            r.lpUnderlyings[0] = token0;
            r.lpUnderlyings[1] = IUniswapV2PairFull(asset).token1();
            r.totalSupply = uint128(IUniswapV2PairFull(asset).totalSupply());
        } catch (bytes memory) { }

        if (owner == address(0)) return r;
        r.balance = uint128(ERC20Like(asset).balanceOf(owner));
    }

    /**
     * @notice Get parameters of many collaterals
     * @param assets asset addresses
     * @param owner owner address
     */
    function getMultiCollateralParameters(address[] calldata assets, address owner)
        external
        view
        returns (CollateralParameters[] memory r)
    {
        uint length = assets.length;
        r = new CollateralParameters[](length);
        for (uint i = 0; i < length; ++i) {
            r[i] = getCollateralParameters(assets[i], owner);
        }
    }

    /**
     * @notice Get details of many token
     * @param assets token addresses
     * @param owner owner address
     */
    function getMultiTokenDetails(address[] calldata assets, address owner)
        external
        view
        returns (TokenDetails[] memory r)
    {
        uint length = assets.length;
        r = new TokenDetails[](length);
        for (uint i = 0; i < length; ++i) {
            r[i] = getTokenDetails(assets[i], owner);
        }
    }
}
