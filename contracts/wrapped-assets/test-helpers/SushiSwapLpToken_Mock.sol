// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";


contract SushiSwapLpToken_Mock is ERC20, ISushiSwapLpToken  {
    address public override token0;
    address public override token1;

    constructor (address _token0, address _token1, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        token0 = _token0;
        token1 = _token1;

        _setupDecimals(decimals_);
        _mint(msg.sender, 100 ether);
    }
}