// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;


/**
 * @title OracleSimple
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract OracleSimple {
    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) public virtual view returns (uint) {}
}


/**
 * @title OracleSimplePoolToken
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract OracleSimplePoolToken is OracleSimple {
    OracleSimple public oracleMainAsset;
}


/**
 * @title ChainlinkedOracleSimple
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 **/
abstract contract ChainlinkedOracleSimple is OracleSimple {
    address public WETH;
    // returns ordinary value
    function ethToUsd(uint ethAmount) public virtual view returns (uint) {}
    // returns Q112-encoded value
    function assetToEth(address asset, uint amount) public virtual view returns (uint) {}
}
