// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./interfaces/IVault.sol";
import "./interfaces/ICollateralRegistry.sol";

/**
 * @title CDPRegistry
 * @dev Contract to manage a registry of collateralized debt positions (CDPs) for the Unit Protocol.
 */
contract CDPRegistry {

    struct CDP {
        address asset;
        address owner;
    }

    mapping (address => address[]) cdpList;
    mapping (address => mapping (address => uint)) cdpIndex;

    IVault public immutable vault;
    ICollateralRegistry public immutable cr;

    event Added(address indexed asset, address indexed owner);
    event Removed(address indexed asset, address indexed owner);

    /**
     * @dev Constructs the CDPRegistry contract.
     * @param _vault Address of the IVault contract.
     * @param _collateralRegistry Address of the ICollateralRegistry contract.
     */
    constructor (address _vault, address _collateralRegistry) {
        require(_vault != address(0) && _collateralRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        vault = IVault(_vault);
        cr = ICollateralRegistry(_collateralRegistry);
    }

    /**
     * @dev Updates the CDP registry for a given asset and owner.
     * @param asset Address of the asset.
     * @param owner Address of the owner.
     */
    function checkpoint(address asset, address owner) public {
        require(asset != address(0) && owner != address(0), "Unit Protocol: ZERO_ADDRESS");

        bool listed = isListed(asset, owner);
        bool alive = isAlive(asset, owner);

        if (alive && !listed) {
            _addCdp(asset, owner);
        } else if (listed && !alive) {
            _removeCdp(asset, owner);
        }
    }

    /**
     * @dev Updates the CDP registry for a given asset and multiple owners.
     * @param asset Address of the asset.
     * @param owners Array of owner addresses.
     */
    function batchCheckpointForAsset(address asset, address[] calldata owners) external {
        for (uint i = 0; i < owners.length; i++) {
            checkpoint(asset, owners[i]);
        }
    }

    /**
     * @dev Updates the CDP registry for multiple assets and owners.
     * @param assets Array of asset addresses.
     * @param owners Array of owner addresses.
     */
    function batchCheckpoint(address[] calldata assets, address[] calldata owners) external {
        require(assets.length == owners.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < owners.length; i++) {
            checkpoint(assets[i], owners[i]);
        }
    }

    /**
     * @dev Checks if a CDP is active.
     * @param asset Address of the asset.
     * @param owner Address of the owner.
     * @return alive Boolean indicating if the CDP is active.
     */
    function isAlive(address asset, address owner) public view returns (bool) {
        return vault.debts(asset, owner) != 0;
    }

    /**
     * @dev Checks if a CDP is listed in the registry.
     * @param asset Address of the asset.
     * @param owner Address of the owner.
     * @return listed Boolean indicating if the CDP is listed.
     */
    function isListed(address asset, address owner) public view returns (bool) {
        if (cdpList[asset].length == 0) { return false; }
        return cdpIndex[asset][owner] != 0 || cdpList[asset][0] == owner;
    }

    /**
     * @dev Internal function to remove a CDP from the registry.
     * @param asset Address of the asset.
     * @param owner Address of the owner.
     */
    function _removeCdp(address asset, address owner) internal {
        uint id = cdpIndex[asset][owner];

        delete cdpIndex[asset][owner];

        uint lastId = cdpList[asset].length - 1;

        if (id != lastId) {
            address lastOwner = cdpList[asset][lastId];
            cdpList[asset][id] = lastOwner;
            cdpIndex[asset][lastOwner] = id;
        }

        cdpList[asset].pop();

        emit Removed(asset, owner);
    }

    /**
     * @dev Internal function to add a CDP to the registry.
     * @param asset Address of the asset.
     * @param owner Address of the owner.
     */
    function _addCdp(address asset, address owner) internal {
        cdpIndex[asset][owner] = cdpList[asset].length;
        cdpList[asset].push(owner);

        emit Added(asset, owner);
    }

    /**
     * @dev Retrieves the list of CDPs for a given collateral.
     * @param asset Address of the asset.
     * @return cdps Array of CDP structs.
     */
    function getCdpsByCollateral(address asset) external view returns (CDP[] memory cdps) {
        address[] memory owners = cdpList[asset];
        cdps = new CDP[](owners.length);
        for (uint i = 0; i < owners.length; i++) {
            cdps[i] = CDP(asset, owners[i]);
        }
    }

    /**
     * @dev Retrieves the list of CDPs for a given owner.
     * @param owner Address of the owner.
     * @return r Array of CDP structs.
     */
    function getCdpsByOwner(address owner) external view returns (CDP[] memory r) {
        address[] memory assets = cr.collaterals();
        CDP[] memory cdps = new CDP[](assets.length);
        uint actualCdpsCount;

        for (uint i = 0; i < assets.length; i++) {
            if (isListed(assets[i], owner)) {
                cdps[actualCdpsCount++] = CDP(assets[i], owner);
            }
        }

        r = new CDP[](actualCdpsCount);

        for (uint i = 0; i < actualCdpsCount; i++) {
            r[i] = cdps[i];
        }
    }

    /**
     * @dev Retrieves the list of all CDPs in the registry.
     * @return r Array of CDP structs.
     */
    function getAllCdps() external view returns (CDP[] memory r) {
        uint totalCdpCount = getCdpsCount();
        
        uint cdpCount;

        r = new CDP[](totalCdpCount);

        address[] memory assets = cr.collaterals();
        for (uint i = 0; i < assets.length; i++) {
            address[] memory owners = cdpList[assets[i]];
            for (uint j = 0; j < owners.length; j++) {
                r[cdpCount++] = CDP(assets[i], owners[j]);
            }
        }
    }

    /**
     * @dev Retrieves the total count of CDPs in the registry.
     * @return totalCdpCount The total count of CDPs.
     */
    function getCdpsCount() public view returns (uint totalCdpCount) {
        address[] memory assets = cr.collaterals();
        for (uint i = 0; i < assets.length; i++) {
            totalCdpCount += cdpList[assets[i]].length;
        }
    }

    /**
     * @dev Retrieves the count of CDPs for a given collateral.
     * @param asset Address of the asset.
     * @return The count of CDPs for the given collateral.
     */
    function getCdpsCountForCollateral(address asset) public view returns (uint) {
        return cdpList[asset].length;
    }
}