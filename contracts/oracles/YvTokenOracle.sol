// SPDX-License-Identifier: bsl-1.1

pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/ERC20Like.sol";
import "../interfaces/IyvToken.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";
import "../VaultParameters.sol";

/**
 * @title YvTokensOracle
 * @dev Wrapper to quote V2 yVault Tokens like yvWETH, yvDAI, yvUSDC, yvUSDT.
 * @dev yVault Tokens list:  https://docs.yearn.finance/yearn-finance/yvaults/vault-tokens#v2-yvault-tokens
 */
contract YvTokenOracle is IOracleUsd, Auth  {
    using SafeMath for uint;

    /// @notice Address of the OracleRegistry contract
    IOracleRegistry public immutable oracleRegistry;

    /**
     * @dev Creates a YvTokenOracle instance.
     * @param _vaultParameters The address of the VaultParameters contract.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     */
    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    /**
     * @notice Converts the amount of the yVault bearing token to its USD value.
     * @param bearing The address of the yVault bearing token.
     * @param amount The amount of the bearing token.
     * @return The USD value of the bearing token amount, encoded in Q112 format.
     * @dev The function reverts if the underlying asset's oracle is not found.
     */
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        (address underlying, uint underlyingAmount) = bearingToUnderlying(bearing, amount);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(underlying));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(underlying, underlyingAmount);
    }

    /**
     * @notice Converts the amount of the yVault bearing token to the underlying asset amount.
     * @param bearing The address of the yVault bearing token.
     * @param amount The amount of the bearing token.
     * @return underlying The address of the underlying asset.
     * @return The amount of the underlying asset.
     * @dev The function reverts if the underlying asset is not defined or if the amount exceeds the total supply.
     */
    function bearingToUnderlying(address bearing, uint amount) public view returns (address, uint) {
        address _underlying = IyvToken(bearing).token();
        require(_underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        uint _totalSupply = ERC20Like(bearing).totalSupply();
        require(amount <= _totalSupply, "Unit Protocol: AMOUNT_EXCEEDS_SUPPLY");
        uint _pricePerShare = IyvToken(bearing).pricePerShare();
        uint _decimals = IyvToken(bearing).decimals();
        return (_underlying, amount.mul(_pricePerShare).div(10**_decimals));
    }

}