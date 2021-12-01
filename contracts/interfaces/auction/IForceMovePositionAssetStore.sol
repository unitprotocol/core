// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IForceMovePositionAssetStore {
    function shouldForceMovePosition ( address ) external view returns ( bool );
    function add ( address asset ) external;
}
