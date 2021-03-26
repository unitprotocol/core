// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;


import "./VaultParameters.sol";


/**
 * @title CollateralRegistry
 **/
contract CollateralRegistry is Auth {

    event CollateralAdded(address indexed asset);
    event CollateralRemoved(address indexed asset);

    mapping(address => uint) public collateralId;

    address[] _collaterals;
    
    constructor(address _vaultParameters) Auth(_vaultParameters) {}

    function addCollateral(address asset) public onlyManager {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");

        require(!isCollateral(asset), "Unit Protocol: ALREADY_EXIST");

        collateralId[asset] = _collaterals.length;
        _collaterals.push(asset);

        emit CollateralAdded(asset);
    }

    function removeCollateral(address asset) public onlyManager {
        require(asset != address(0), "Unit Protocol: ZERO_ADDRESS");

        uint id = collateralId[asset];
        require(isCollateral(asset), "Unit Protocol: DOES_NOT_EXIST");

        delete collateralId[asset];

        uint lastId = _collaterals.length - 1;
        address lastCollateral = _collaterals[lastId];

        if (id != lastId) {
            _collaterals[id] = lastCollateral;
            collateralId[lastCollateral] = id;
        }

        _collaterals.pop();

        emit CollateralRemoved(asset);
    }

    function isCollateral(address asset) public view returns(bool) {
        if (_collaterals.length == 0) { return false; }
        return collateralId[asset] != 0 || _collaterals[0] == asset;
    }

    function collaterals() external view returns (address[] memory) {
        return _collaterals;
    }
}
