// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "./EmptyToken.sol";
import "../interfaces/IStETH.sol";

/**
 * @title StETH
 * @dev Implementation of a staked ETH token.
 */
contract StETH is IStETH, EmptyToken {
  using SafeMath for uint;

  /// @notice Total amount of pooled Ether in the contract.
  uint256 public totalPooledEther;

  /// @dev Position of the total shares in contract storage.
  bytes32 internal constant TOTAL_SHARES_POSITION = keccak256("lido.StETH.totalShares");

  /**
   * @notice Constructs the stETH token contract.
   * @param _totalPooledEther Initial amount of pooled Ether.
   * @param _totalShares Initial amount of shares.
   */
  constructor(
    uint256 _totalPooledEther,
    uint256 _totalShares
  ) EmptyToken(
    "Liquid staked Ether 2.0",
    "stETH",
    18,
    _totalShares,
    msg.sender
  ) {
    totalPooledEther = _totalPooledEther;
    _mintShares(_totalShares);
  }

  /**
   * @dev Internal function to set a uint256 into contract storage.
   * @param position Storage position to write to.
   * @param data The uint256 data to write into storage.
   */
  function setStorageUint256(bytes32 position, uint256 data) internal {
    assembly { sstore(position, data) }
  }

  /**
   * @dev Internal function to mint shares.
   * @param _sharesAmount The amount of shares to mint.
   * @return newTotalShares The new total shares after minting.
   */
  function _mintShares(uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    newTotalShares = _getTotalShares().add(_sharesAmount);
    setStorageUint256(TOTAL_SHARES_POSITION, newTotalShares);
  }

  /**
   * @dev Internal view function to get a uint256 from contract storage.
   * @param position Storage position to read from.
   * @return data The uint256 data read from storage.
   */
  function getStorageUint256(bytes32 position) internal view returns (uint256 data) {
    assembly { data := sload(position) }
  }

  /**
   * @dev Internal view function to get the total shares.
   * @return The total shares stored in the contract.
   */
  function _getTotalShares() internal view returns (uint256) {
    return getStorageUint256(TOTAL_SHARES_POSITION);
  }

  /**
   * @dev Internal view function to get the total pooled Ether.
   * @return The total pooled Ether stored in the contract.
   */
  function _getTotalPooledEther() internal view returns (uint256) {
    return totalPooledEther;
  }

  /**
   * @notice Calculates the amount of pooled Ether corresponding to the given shares.
   * @param _sharesAmount The amount of shares.
   * @return The amount of pooled Ether that corresponds to the given shares.
   */
  function getPooledEthByShares(uint256 _sharesAmount) public override view returns (uint256) {
    uint256 totalShares = _getTotalShares();
    if (totalShares == 0) {
      return 0;
    } else {
      return _sharesAmount
      .mul(_getTotalPooledEther())
      .div(totalShares);
    }
  }

}