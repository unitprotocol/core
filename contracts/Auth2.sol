// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./VaultParameters.sol";


/**
 * @title Auth2
 * @dev Manages USDP's system access
 * @dev copy of Auth from VaultParameters.sol but with immutable vaultParameters for saving gas
 **/
contract Auth2 {

    // address of the the contract with vault parameters
    VaultParameters public immutable vaultParameters;

    constructor(address _parameters) {
        vaultParameters = VaultParameters(_parameters);
    }

    // ensures tx's sender is a manager
    modifier onlyManager() {
        require(vaultParameters.isManager(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is able to modify the Vault
    modifier hasVaultAccess() {
        require(vaultParameters.canModifyVault(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is the Vault
    modifier onlyVault() {
        require(msg.sender == vaultParameters.vault(), "Unit Protocol: AUTH_FAILED");
        _;
    }
}
