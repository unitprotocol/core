// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.6;

interface IForceTransferAssetStore {
    function shouldForceTransfer ( address ) external view returns ( bool );
    function add ( address asset ) external;
}
