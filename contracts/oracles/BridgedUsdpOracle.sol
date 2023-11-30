// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../helpers/SafeMath.sol";
import "../Auth2.sol";

/* 
 * @title BridgedUSDPOracle
 * @dev Oracle to quote bridged from other chains USDP. Implements the IOracleUsd interface.
 */
contract BridgedUsdpOracle is IOracleUsd, Auth2 {
    using SafeMath for uint;

    // Q112 is used to store values with 112 decimal places.
    uint public constant Q112 = 2 ** 112;

    // Mapping to keep track of addresses that are recognized as bridged USDP tokens.
    mapping (address => bool) public bridgedUsdp;

    // Event emitted when a new USDP address is added.
    event Added(address _usdp);
    // Event emitted when an existing USDP address is removed.
    event Removed(address _usdp);

    /**
     * @dev Constructor that initializes the contract's state.
     * @param vaultParameters The address of the contract containing vault parameters.
     * @param _bridgedUsdp Array of addresses to be initially recognized as bridged USDP tokens.
     */
    constructor(address vaultParameters, address[] memory _bridgedUsdp) Auth2(vaultParameters) {
        for (uint i = 0; i < _bridgedUsdp.length; i++) {
            _add(_bridgedUsdp[i]);
        }
    }

    /**
     * @dev Adds a new USDP address to the list of recognized bridged USDP tokens. Only the manager can call it.
     * @param _usdp The address of the USDP token to add.
     */
    function add(address _usdp) external onlyManager {
        _add(_usdp);
    }

    /**
     * @dev Internal function to add a new USDP address to the list of recognized bridged USDP tokens.
     * @param _usdp The address of the USDP token to add.
     */
    function _add(address _usdp) private {
        require(_usdp != address(0), 'Unit Protocol: ZERO_ADDRESS');
        require(!bridgedUsdp[_usdp], 'Unit Protocol: ALREADY_ADDED');

        bridgedUsdp[_usdp] = true;
        emit Added(_usdp);
    }

    /**
     * @dev Removes a USDP address from the list of recognized bridged USDP tokens. Only the manager can call it.
     * @param _usdp The address of the USDP token to remove.
     */
    function remove(address _usdp) external onlyManager {
        require(_usdp != address(0), 'Unit Protocol: ZERO_ADDRESS');
        require(bridgedUsdp[_usdp], 'Unit Protocol: WAS_NOT_ADDED');

        bridgedUsdp[_usdp] = false;
        emit Removed(_usdp);
    }

    /**
     * @dev Converts the asset amount to the equivalent USD value. The returned value is Q112-encoded.
     * @param asset The address of the asset to convert.
     * @param amount The amount of the asset to convert.
     * @return The equivalent USD value of the asset amount, Q112-encoded.
     */
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        require(bridgedUsdp[asset], 'Unit Protocol: TOKEN_IS_NOT_SUPPORTED');
        return amount.mul(Q112);
    }
}