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
 **/
contract BearingAssetOracle is IOracleUsd, Auth {

    IOracleRegistry public immutable oracleRegistry;

    mapping (address => address) underlyings;

    event NewUnderlying(address indexed bearing, address indexed underlying);

    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    function setUnderlying(address bearing, address underlying) external onlyManager {
        underlyings[bearing] = underlying;
        emit NewUnderlying(bearing, underlying);
    }

    // returns Q112-encoded value
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        (address underlying, uint underlyingAmount) = bearingToUnderlying(bearing, amount);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(underlying));
        return _oracleForUnderlying.assetToUsd(underlying, underlyingAmount);
    }

    function bearingToUnderlying(address bearing, uint amount) public view returns (address, uint) {
        address _underlying = underlyings[bearing];
        require(_underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        uint _reserve = ERC20Like(_underlying).balanceOf(address(bearing));
        uint _totalSupply = ERC20Like(bearing).totalSupply();
        require(amount <= _totalSupply, "Unit Protocol: AMOUNT_EXCEEDS_SUPPLY");
        return (_underlying, amount * _reserve / _totalSupply);
    }

}
