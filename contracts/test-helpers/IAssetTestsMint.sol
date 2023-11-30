// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

/**
 * @title IAssetTestsMint
 * @dev Interface for a contract that allows for minting of a particular asset.
 */
interface IAssetTestsMint {

    /**
     * @dev Mints the specified amount of the asset to the given user address.
     * @param _user The address of the user to receive the minted assets.
     * @param _amount The amount of the asset to be minted.
     */
    function tests_mint(address _user, uint _amount) external;
}