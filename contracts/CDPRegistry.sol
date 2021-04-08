// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./interfaces/IVault.sol";
import "./interfaces/ICollateralRegistry.sol";


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

    constructor (address _vault, address _collateralRegistry) {
        require(_vault != address(0) && _collateralRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        vault = IVault(_vault);
        cr = ICollateralRegistry(_collateralRegistry);
    }

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

    function batchCheckpointForAsset(address asset, address[] calldata owners) external {
        for (uint i = 0; i < owners.length; i++) {
            checkpoint(asset, owners[i]);
        }
    }

    function batchCheckpoint(address[] calldata assets, address[] calldata owners) external {
        require(assets.length == owners.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < owners.length; i++) {
            checkpoint(assets[i], owners[i]);
        }
    }

    function isAlive(address asset, address owner) public view returns (bool) {
        return vault.debts(asset, owner) != 0;
    }

    function isListed(address asset, address owner) public view returns (bool) {
        if (cdpList[asset].length == 0) { return false; }
        return cdpIndex[asset][owner] != 0 || cdpList[asset][0] == owner;
    }

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

    function _addCdp(address asset, address owner) internal {
        cdpIndex[asset][owner] = cdpList[asset].length;
        cdpList[asset].push(owner);

        emit Added(asset, owner);
    }

    function getCdpsByCollateral(address asset) external view returns (CDP[] memory cdps) {
        address[] memory owners = cdpList[asset];
        cdps = new CDP[](owners.length);
        for (uint i = 0; i < owners.length; i++) {
            cdps[i] = CDP(asset, owners[i]);
        }
    }

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

    function getCdpsCount() public view returns (uint totalCdpCount) {
        address[] memory assets = cr.collaterals();
        for (uint i = 0; i < assets.length; i++) {
            totalCdpCount += cdpList[assets[i]].length;
        }
    }

    function getCdpsCountForCollateral(address asset) public view returns (uint) {
        return cdpList[asset].length;
    }
}