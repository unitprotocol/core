// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "./KeydonixOracleAbstract.sol";
pragma experimental ABIEncoderV2;


/**
 * @title ChainlinkedKeydonixOracleMainAssetAbstract
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract ChainlinkedKeydonixOracleMainAssetAbstract is KeydonixOracleAbstract {

    address public WETH;

    function assetToEth(
        address asset,
        uint amount,
        ProofDataStruct memory proofData
    ) public virtual view returns (uint);

    function ethToUsd(uint ethAmount) public virtual view returns (uint);
}
