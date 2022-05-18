// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../helpers/SafeMath.sol";
import "../Auth2.sol";

/**
 * @title BridgedUSDPOracle
 * @dev Oracle to quote bridged from other chains USDP
 **/
contract BridgedUsdpOracle is IOracleUsd, Auth2 {
    using SafeMath for uint;

    uint public constant Q112 = 2 ** 112;

    mapping (address => bool) public bridgedUsdp;

    event Added(address _usdp);
    event Removed(address _usdp);

    constructor(address vaultParameters, address[] memory _bridgedUsdp) Auth2(vaultParameters) {
        for (uint i = 0; i < _bridgedUsdp.length; i++) {
            _add(_bridgedUsdp[i]);
        }
    }

    function add(address _usdp) external onlyManager {
        _add(_usdp);
    }

    function _add(address _usdp) private {
        require(_usdp != address(0), 'Unit Protocol: ZERO_ADDRESS');
        require(!bridgedUsdp[_usdp], 'Unit Protocol: ALREADY_ADDED');

        bridgedUsdp[_usdp] = true;
        emit Added(_usdp);
    }

    function remove(address _usdp) external onlyManager {
        require(_usdp != address(0), 'Unit Protocol: ZERO_ADDRESS');
        require(bridgedUsdp[_usdp], 'Unit Protocol: WAS_NOT_ADDED');

        bridgedUsdp[_usdp] = false;
        emit Removed(_usdp);
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        require(bridgedUsdp[asset], 'Unit Protocol: TOKEN_IS_NOT_SUPPORTED');
        return amount.mul(Q112);
    }
}
