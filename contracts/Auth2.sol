// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./VaultParameters.sol";

/**
 * @title Auth2
 * @notice Auth2 is a contract that manages USDP's system access with immutable vaultParameters for gas optimization.
 * @dev Inherits VaultParameters contract's properties for access control.
 * @dev Copy of Auth from VaultParameters.sol but with immutable vaultParameters for saving gas
 */
contract Auth2 {

    /**
     * @notice The VaultParameters contract which holds system parameters.
     * @dev Immutable to save gas, as it's set only once upon construction and cannot be changed afterwards.
     */
    VaultParameters public immutable vaultParameters;

    /**
     * @notice Constructs the Auth2 contract.
     * @param _parameters The address of the VaultParameters contract.
     */
    constructor(address _parameters) {
        require(_parameters != address(0), "Unit Protocol: ZERO_ADDRESS");
        vaultParameters = VaultParameters(_parameters);
    }

    /**
     * @notice Ensures the transaction's sender is a manager.
     * @dev Modifier that throws if the sender is not a manager.
     */
    modifier onlyManager() {
        require(vaultParameters.isManager(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    /**
     * @notice Ensures the transaction's sender has access to modify the Vault.
     * @dev Modifier that throws if the sender cannot modify the Vault.
     */
    modifier hasVaultAccess() {
        require(vaultParameters.canModifyVault(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    /**
     * @notice Ensures the transaction's sender is the Vault itself.
     * @dev Modifier that throws if the sender is not the Vault.
     */
    modifier onlyVault() {
        require(msg.sender == vaultParameters.vault(), "Unit Protocol: AUTH_FAILED");
        _;
    }
}