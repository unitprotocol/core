// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./VaultParameters.sol";

/**
 * @title CollateralRegistry
 * @dev Manages a registry of collateral assets for Unit Protocol.
 */
contract CollateralRegistry is Auth {

    /**
     * @dev Emitted when a new collateral is added to the registry.
     * @param asset The address of the collateral asset added.
     */
    event CollateralAdded(address indexed asset);

    /**
     * @dev Emitted when a collateral is removed from the registry.
     * @param asset The address of the collateral asset removed.
     */
    event CollateralRemoved(address indexed asset);

    /**
     * @dev Mapping from collateral asset addresses to their respective ID.
     */
    mapping(address => uint) public collateralId;

    /**
     * @dev List of all collateral asset addresses.
     */
    address[] public collateralList;

    /**
     * @dev Initializes the contract with a list of collateral assets.
     * @param _vaultParameters The address of the VaultParameters contract.
     * @param assets The initial list of collateral asset addresses.
     */
    constructor(address _vaultParameters, address[] memory assets) Auth(_vaultParameters) {
        for (uint i = 0; i < assets.length; i++) {
            require(!isCollateral(assets[i]), "Unit Protocol: ALREADY_EXIST");
            collateralList.push(assets[i]);
            collateralId[assets[i]] = i;
            emit CollateralAdded(assets[i]);
        }
    }

    /**
     * @dev Adds a new collateral asset to the registry.
     * @param asset The address of the collateral asset to add.
     * @notice Only the manager can call this function.
     */
    function addCollateral(address asset) public onlyManager {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(!isCollateral(asset), "Unit Protocol: ALREADY_EXIST");
        collateralId[asset] = collateralList.length;
        collateralList.push(asset);
        emit CollateralAdded(asset);
    }

    /**
     * @dev Removes a collateral asset from the registry.
     * @param asset The address of the collateral asset to remove.
     * @notice Only the manager can call this function.
     */
    function removeCollateral(address asset) public onlyManager {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(isCollateral(asset), "Unit Protocol: DOES_NOT_EXIST");
        uint id = collateralId[asset];
        delete collateralId[asset];
        uint lastId = collateralList.length - 1;
        if (id != lastId) {
            address lastCollateral = collateralList[lastId];
            collateralList[id] = lastCollateral;
            collateralId[lastCollateral] = id;
        }
        collateralList.pop();
        emit CollateralRemoved(asset);
    }

    /**
     * @dev Checks if an address is a collateral in the registry.
     * @param asset The address to check.
     * @return True if the address is a collateral, false otherwise.
     */
    function isCollateral(address asset) public view returns(bool) {
        if (collateralList.length == 0) { return false; }
        return collateralId[asset] != 0 || collateralList[0] == asset;
    }

    /**
     * @dev Returns the list of all collateral assets in the registry.
     * @return An array of addresses of the collateral assets.
     */
    function collaterals() external view returns (address[] memory) {
        return collateralList;
    }

    /**
     * @dev Returns the count of collateral assets in the registry.
     * @return The count of collateral assets.
     */
    function collateralsCount() external view returns (uint) {
        return collateralList.length;
    }
}