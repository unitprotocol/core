// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./OracleSimple.sol";
import "../helpers/ERC20Like.sol";
import "./OracleRegistry.sol";

/**
 * @title WrappedToUnderlyingOracle
 * @dev Oracle to quote wrapped tokens to underlying
 **/
contract WrappedToUnderlyingOracle is OracleSimple, Auth {

    OracleRegistry public immutable oracleRegistry;

    event NewUnderlying(address indexed wrapped, address indexed underlying);

    mapping (address => address) public assetToUnderlying;

    constructor(address _vaultParameters, address _oracleRegistry) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = OracleRegistry(_oracleRegistry);
    }

    function setUnderlying(address wrapped, address underlying) external onlyManager {
        assetToUnderlying[wrapped] = underlying;
        emit NewUnderlying(wrapped, underlying);
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        address underlying = assetToUnderlying[asset];
        require(underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        
        OracleSimple _oracleForUnderlying = OracleSimple(oracleRegistry.oracleByAsset(underlying));
        return _oracleForUnderlying.assetToUsd(underlying, amount);
    }

}
