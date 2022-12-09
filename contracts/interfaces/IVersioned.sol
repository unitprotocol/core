// SPDX-License-Identifier: bsl-1.1
/**
 * Copyright 2022 Unit Protocol V2: Artem Zakharov (hello@unit.xyz).
 */
pragma solidity ^0.7.1;

/// @title Contract supporting versioning using SemVer version scheme.
interface IVersioned {
    /// @notice Contract version, using SemVer version scheme.
    function VERSION() external view returns (string memory);
}
