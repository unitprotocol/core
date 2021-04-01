// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/IUniswapV2PairFull.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IOracleSimple.sol";
import "../interfaces/IOracleEth.sol";
import "../interfaces/IOracleRegistry.sol";

/**
 * @title OraclePoolToken_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract OraclePoolToken_Mock is IOracleSimple {
    using SafeMath for uint;
    uint public immutable Q112 = 2 ** 112;

    IOracleRegistry public oracleRegistry;

    address public immutable WETH;

    constructor(address _oracleRegistry, address _weth) public {
        require(_oracleRegistry != address(0) && _weth != address(0), "Unit Protocol: INVALID_ARGS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        WETH = _weth;
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        uint ePool; // current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == WETH) {
            ePool = _reserve0;
        } else if (pair.token1() == WETH) {
            ePool = _reserve1;
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        uint lpSupply = pair.totalSupply();
        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112);

        return IOracleEth(oracleRegistry.oracleByAsset(WETH)).ethToUsd(totalValueInEth_q112).div(lpSupply);
    }
}
