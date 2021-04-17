// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../helpers/IUniswapV2PairFull.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IKeydonixOracleUsd.sol";
import "../interfaces/IVaultParameters.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";

/**
 * @title KeydonixOraclePoolToken_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract KeydonixOraclePoolToken_Mock is IKeydonixOracleUsd {
    using SafeMath for uint;

    uint public constant Q112 = 2 ** 112;

    IOracleRegistry public immutable oracleRegistry;

    IVaultParameters public immutable vaultParameters;

    constructor(address _oracleRegistry, address _vaultParameters) public {
        require(_oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(_vaultParameters != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        vaultParameters = IVaultParameters(_vaultParameters);
    }

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount, ProofDataStruct calldata proofData) public override view returns (uint) {

        IUniswapV2PairFull pair = IUniswapV2PairFull(asset);

        proofData;

        uint ePool; // current WETH pool

        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();

        if (pair.token0() == oracleRegistry.WETH()) {
            ePool = _reserve0;
        } else if (pair.token1() == oracleRegistry.WETH()) {
            ePool = _reserve1;
        } else {
            revert("Unit Protocol: NOT_REGISTERED_PAIR");
        }

        uint lpSupply = pair.totalSupply();
        uint totalValueInEth_q112 = amount.mul(ePool).mul(2).mul(Q112);

        return IOracleEth(oracleRegistry.oracleByAsset(oracleRegistry.WETH())).ethToUsd(totalValueInEth_q112).div(lpSupply);
    }

    function _selectOracle(address asset) internal view returns (address oracle) {
        uint oracleType = _getOracleType(asset);
        require(oracleType != 0, "Unit Protocol: INVALID_ORACLE_TYPE");
        oracle = oracleRegistry.oracleByType(oracleType);
        require(oracle != address(0), "Unit Protocol: DISABLED_ORACLE");
    }

    function _getOracleType(address asset) internal view returns (uint) {
        uint[] memory keydonixOracleTypes = oracleRegistry.getKeydonixOracleTypes();
        for (uint i = 0; i < keydonixOracleTypes.length; i++) {
            if (vaultParameters.isOracleTypeEnabled(keydonixOracleTypes[i], asset)) {
                return keydonixOracleTypes[i];
            }
        }
        revert("Unit Protocol: NO_ORACLE_FOUND");
    }
}
