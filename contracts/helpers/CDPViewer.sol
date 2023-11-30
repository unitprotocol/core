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
import "../interfaces/wrapped-assets/IWrappedAsset.sol";
import "./IUniswapV2PairFull.sol";
import "./ERC20Like.sol";


/**
 * @title CDPViewer
 * @notice Provides batch views for collateral debt positions (CDPs) and token details to optimize node requests.
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
        address[2] lpUnderlyings; // Addresses of underlying tokens for LP tokens
        uint128 balance; // Token balance of the owner
        uint128 totalSupply; // Total supply of the token
        uint8 decimals; // Decimals of the token
        address uniswapV2Factory; // Address of the Uniswap V2 factory
        address underlyingToken; // Address of the underlying token for wrapped tokens
        uint256 underlyingTokenBalance; // Balance of the underlying token
        uint256 underlyingTokenTotalSupply; // Total supply of the underlying token
        uint8 underlyingTokenDecimals; // Decimals of the underlying token
        address underlyingTokenUniswapV2Factory; // Uniswap V2 factory for the underlying token
        address[2] underlyingTokenUnderlyings; // Underlying tokens for the underlying LP token
    }

    /**
     * @dev Initializes the contract by setting the vault manager parameters, oracle registry, and vault manager borrow fee parameters.
     * @param _vaultManagerParameters Address of the vault manager parameters contract.
     * @param _oracleRegistry Address of the oracle registry contract.
     * @param _vaultManagerBorrowFeeParameters Address of the vault manager borrow fee parameters contract.
     */
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
     * @notice Retrieves parameters and CDP information for a given asset and owner.
     * @param asset The address of the asset to query.
     * @param owner The address of the owner to query.
     * @return r The CollateralParameters structure containing the requested information.
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
     * @notice Retrieves token details for a given asset and optionally for an owner's balance.
     * @param asset The address of the token to query.
     * @param owner The address of the owner to query, or zero address for no balance query.
     * @return r The TokenDetails structure containing the requested information.
     */
    function getTokenDetails(address asset, address owner)
        public
        view
        returns (TokenDetails memory r)
    {
        address token0;
        address token1;

        (bool success, bytes memory data) = asset.staticcall{gas:20000}(abi.encodeWithSignature("token0()"));
        if (success && data.length == 32) { // check in this way (and not try/catch) since some tokens has fallback functions
            token0 = bytesToAddress(data);

            (success, data) = asset.staticcall{gas:20000}(abi.encodeWithSignature("token1()"));
            if (success && data.length == 32) {
                token1 = bytesToAddress(data);

                (success, data) = asset.staticcall{gas:20000}(abi.encodeWithSignature("factory()"));
                if (success && data.length == 32) {
                    r.lpUnderlyings[0] = token0;
                    r.lpUnderlyings[1] = token1;
                    r.uniswapV2Factory = bytesToAddress(data);
                }
            }
        }

        r.totalSupply = uint128(IUniswapV2PairFull(asset).totalSupply());
        r.decimals = uint8(IUniswapV2PairFull(asset).decimals());
        if (owner != address(0)) {
            r.balance = uint128(ERC20Like(asset).balanceOf(owner));
        }

        (success, data) = asset.staticcall{gas:20000}(abi.encodeWithSignature("isUnitProtocolWrappedAsset()"));
        if (success && data.length == 32 && bytesToBytes32(data) == keccak256("UnitProtocolWrappedAsset")) {
            r.underlyingToken = address(IWrappedAsset(asset).getUnderlyingToken());

            TokenDetails memory underlyingTokenDetails = getTokenDetails(r.underlyingToken, owner);
            r.underlyingTokenTotalSupply = underlyingTokenDetails.totalSupply;
            r.underlyingTokenDecimals = underlyingTokenDetails.decimals;
            r.underlyingTokenBalance = underlyingTokenDetails.balance;
            r.underlyingTokenUniswapV2Factory = underlyingTokenDetails.uniswapV2Factory;
            r.underlyingTokenUnderlyings[0] = underlyingTokenDetails.lpUnderlyings[0];
            r.underlyingTokenUnderlyings[1] = underlyingTokenDetails.lpUnderlyings[1];
        }
    }

    /**
     * @dev Converts bytes to an address.
     * @param _bytes The bytes to convert.
     * @return addr The converted address.
     */
    function bytesToAddress(bytes memory _bytes) private pure returns (address addr) {
        assembly {
          addr := mload(add(_bytes, 32))
        }
    }

    /**
     * @dev Converts bytes to a bytes32.
     * @param _bytes The bytes to convert.
     * @return _bytes32 The converted bytes32.
     */
    function bytesToBytes32(bytes memory _bytes) private pure returns (bytes32 _bytes32) {
        assembly {
          _bytes32 := mload(add(_bytes, 32))
        }
    }

    /**
     * @notice Retrieves parameters for multiple collaterals and an owner.
     * @param assets An array of asset addresses to query.
     * @param owner The address of the owner to query.
     * @return r An array of CollateralParameters structures containing the requested information.
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
     * @notice Retrieves details for multiple tokens and optionally for an owner's balances.
     * @param assets An array of token addresses to query.
     * @param owner The address of the owner to query, or zero address for no balance query.
     * @return r An array of TokenDetails structures containing the requested information.
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