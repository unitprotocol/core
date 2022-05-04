// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IWrappedAssetInternal.sol";

/**
 * @dev for usage with upgradeable/clones contracts. Methods/events must be the same as in IWrappedAsset
 * @dev For dependencies in unit protocol use IWrappedAsset
 */
interface IWrappedAssetUpgradeable is IERC20Upgradeable, IWrappedAssetInternal /* IERC20WithOptional */ {
}
