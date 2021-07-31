// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/IOracleUsd.sol";
import "../helpers/SafeMath.sol";

/**
 * @title UsdpOracle
 * @dev Oracle to quote USDP token
 **/
contract UsdpOracle is IOracleUsd {
    using SafeMath for uint;

    uint public constant Q112 = 2 ** 112;

    // USDP token contract
    address public immutable usdp;

    constructor( address _usdp) {
        require(_usdp != address(0), "Unit Protocol: ZERO_ADDRESS");
        usdp = _usdp;
    }

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        require(asset == usdp, "Unit Protocol: ASSET_IS_NOT_USDP");
        if (amount == 0) return 0;
        return amount.mul(Q112);
    }

}
