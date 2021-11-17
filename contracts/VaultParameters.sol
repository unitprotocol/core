// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./interfaces/IVaultParameters.sol";
import "./Auth.sol";

/**
 * @title VaultParameters
 **/
contract VaultParameters is IVaultParameters, Auth   {

    // map token to stability fee percentage; 3 decimals
    mapping(address => uint) public override stabilityFee;

    // map token to liquidation fee percentage, 0 decimals
    mapping(address => uint) public override liquidationFee;

    // map token to USDP mint limit
    mapping(address => uint) public override tokenDebtLimit;

    // permissions to modify the Vault
    mapping(address => bool) public override canModifyVault;

    // managers
    mapping(address => bool) public override isManager;

    // enabled oracle types
    mapping(uint => mapping (address => bool)) public override isOracleTypeEnabled;

    // address of the Vault
    address payable public immutable override vault;

    // The foundation address
    address public override foundation;

    /**
     * The address for an Ethereum contract is deterministically computed from the address of its creator (sender)
     * and how many transactions the creator has sent (nonce). The sender and nonce are RLP encoded and then
     * hashed with Keccak-256.
     * Therefore, the Vault address can be pre-computed and passed as an argument before deployment.
    **/
    constructor(address payable _vault, address _foundation) Auth(address(this)) {
        require(_vault != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(_foundation != address(0), "Unit Protocol: ZERO_ADDRESS");

        isManager[msg.sender] = true;
        vault = _vault;
        foundation = _foundation;
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Grants and revokes manager's status of any address
     * @param who The target address
     * @param permit The permission flag
     **/
    function setManager(address who, bool permit) external override onlyManager {
        isManager[who] = permit;

        if (permit) {
            emit ManagerAdded(who);
        } else {
            emit ManagerRemoved(who);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the foundation address
     * @param newFoundation The new foundation address
     **/
    function setFoundation(address newFoundation) external override onlyManager {
        require(newFoundation != address(0), "Unit Protocol: ZERO_ADDRESS");
        foundation = newFoundation;

        emit FoundationChanged(newFoundation);
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets ability to use token as the main collateral
     * @param asset The address of the main collateral token
     * @param stabilityFeeValue The percentage of the year stability fee (3 decimals)
     * @param liquidationFeeValue The liquidation fee percentage (0 decimals)
     * @param usdpLimit The USDP token issue limit
     * @param oracles The enables oracle types
     **/
    function setCollateral(
        address asset,
        uint stabilityFeeValue,
        uint liquidationFeeValue,
        uint usdpLimit,
        uint[] calldata oracles
    ) external override onlyManager {
        setStabilityFee(asset, stabilityFeeValue);
        setLiquidationFee(asset, liquidationFeeValue);
        setTokenDebtLimit(asset, usdpLimit);
        for (uint i=0; i < oracles.length; i++) {
            setOracleType(oracles[i], asset, true);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets a permission for an address to modify the Vault
     * @param who The target address
     * @param permit The permission flag
     **/
    function setVaultAccess(address who, bool permit) external override onlyManager {
        canModifyVault[who] = permit;

        if (permit) {
            emit VaultAccessGranted(who);
        } else {
            emit VaultAccessRevoked(who);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentage of the year stability fee for a particular collateral
     * @param asset The address of the main collateral token
     * @param newValue The stability fee percentage (3 decimals)
     **/
    function setStabilityFee(address asset, uint newValue) public override onlyManager {
        stabilityFee[asset] = newValue;

        emit StabilityFeeChanged(asset, newValue);
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentage of the liquidation fee for a particular collateral
     * @param asset The address of the main collateral token
     * @param newValue The liquidation fee percentage (0 decimals)
     **/
    function setLiquidationFee(address asset, uint newValue) public override onlyManager {
        require(newValue <= 100, "Unit Protocol: VALUE_OUT_OF_RANGE");
        liquidationFee[asset] = newValue;

        emit LiquidationFeeChanged(asset, newValue);
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Enables/disables oracle types
     * @param _type The type of the oracle
     * @param asset The address of the main collateral token
     * @param enabled The control flag
     **/
    function setOracleType(uint _type, address asset, bool enabled) public override onlyManager {
        isOracleTypeEnabled[_type][asset] = enabled;

        if (enabled) {
            emit OracleTypeEnabled(asset, _type);
        } else {
            emit OracleTypeDisabled(asset, _type);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets USDP limit for a specific collateral
     * @param asset The address of the main collateral token
     * @param limit The limit number
     **/
    function setTokenDebtLimit(address asset, uint limit) public override onlyManager {
        tokenDebtLimit[asset] = limit;

        emit TokenDebtLimitChanged(asset, limit);
    }
}
