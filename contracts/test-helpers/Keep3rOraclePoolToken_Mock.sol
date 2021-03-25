// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../helpers/IUniswapV2PairFull.sol";
import "../helpers/SafeMath.sol";
import "../oracles/OracleSimple.sol";

/**
 * @title Keep3rOraclePoolToken_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract Keep3rOraclePoolToken_Mock is OracleSimplePoolToken {
    using SafeMath for uint;
    uint public immutable Q112 = 2 ** 112;

    constructor(address _keep3rOracleMainAsset_Mock) public {
        oracleMainAsset = ChainlinkedOracleSimple(_keep3rOracleMainAsset_Mock);
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        uint ePool; // current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == oracleMainAsset.WETH()) {
            ePool = _reserve0;
        } else if (pair.token1() == oracleMainAsset.WETH()) {
            ePool = _reserve1;
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        uint lpSupply = pair.totalSupply();
        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112);

        return oracleMainAsset.ethToUsd(totalValueInEth_q112).div(lpSupply);
    }
}
