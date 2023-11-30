// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../helpers/ERC20Like.sol";
import "../VaultParameters.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";

/**
 * @title BearingAssetOracle
 * @dev Wrapper to quote bearing assets like xSUSHI
 */
contract BearingAssetOracle is IOracleUsd, Auth  {

    IOracleRegistry public immutable oracleRegistry;

    // Maps bearing asset to its underlying asset
    mapping (address => address) underlyings;

    /**
     * @dev Emitted when a new underlying is set for a bearing asset.
     * @param bearing The address of the bearing asset
     * @param underlying The address of the underlying asset
     */
    event NewUnderlying(address indexed bearing, address indexed underlying);

    /**
     * @dev Constructs the BearingAssetOracle contract.
     * @param _vaultParameters The address of the VaultParameters contract
     * @param _oracleRegistry The address of the OracleRegistry contract
     */
    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    /**
     * @dev Sets the underlying asset for a given bearing asset.
     * @notice Only the manager can call this function.
     * @param bearing The address of the bearing asset
     * @param underlying The address of the underlying asset
     */
    function setUnderlying(address bearing, address underlying) external onlyManager {
        underlyings[bearing] = underlying;
        emit NewUnderlying(bearing, underlying);
    }

    /**
     * @dev Returns the USD value of the bearing asset provided.
     * @notice Returns a Q112-encoded value (to maintain precision).
     * @param bearing The address of the bearing asset
     * @param amount The amount of the bearing asset
     * @return The USD value of the bearing asset amount provided
     */
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        (address underlying, uint underlyingAmount) = bearingToUnderlying(bearing, amount);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(underlying));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(underlying, underlyingAmount);
    }

    /**
     * @dev Converts the amount of bearing asset into the equivalent amount of its underlying asset.
     * @param bearing The address of the bearing asset
     * @param amount The amount of the bearing asset
     * @return The address of the underlying asset and the equivalent amount of the underlying asset
     */
    function bearingToUnderlying(address bearing, uint amount) public view returns (address, uint) {
        address _underlying = underlyings[bearing];
        require(_underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        uint _reserve = ERC20Like(_underlying).balanceOf(address(bearing));
        uint _totalSupply = ERC20Like(bearing).totalSupply();
        require(amount <= _totalSupply, "Unit Protocol: AMOUNT_EXCEEDS_SUPPLY");
        return (_underlying, amount * _reserve / _totalSupply);
    }

}