// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../../helpers/UnitERC20.sol";
import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";


contract SushiSwapLpToken_Mock is UnitERC20, ISushiSwapLpToken  {
    address public override token0;
    address public override token1;

    constructor (address _token0, address _token1, string memory name_, string memory symbol_)
        UnitERC20(18)
    {
        token0 = _token0;
        token1 = _token1;
        _initNameAndSymbol(name_, symbol_);

        _mint(msg.sender, 100 ether);
    }
}