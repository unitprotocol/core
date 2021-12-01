// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../IERC20WithOptional.sol";

interface ISushiSwapLpToken is IERC20WithOptional {
    function token0() external view returns (address);
    function token1() external view returns (address);
}