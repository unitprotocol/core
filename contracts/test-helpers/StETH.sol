// SPDX-License-Identifier: bsl-1.1

/*
Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/

pragma solidity 0.7.6;

import "./EmptyToken.sol";
import "../interfaces/IStETH.sol";

contract StETH is IStETH, EmptyToken {
  using SafeMath for uint;

  uint256 public totalPooledEther;
  bytes32 internal constant TOTAL_SHARES_POSITION = keccak256("lido.StETH.totalShares");

  constructor(
    uint256          _totalPooledEther,
    uint256          _totalShares
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

  function setStorageUint256(bytes32 position, uint256 data) internal {
    assembly { sstore(position, data) }
  }

  function _mintShares(uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    newTotalShares = _getTotalShares().add(_sharesAmount);
    setStorageUint256(TOTAL_SHARES_POSITION, newTotalShares);
  }

  function getStorageUint256(bytes32 position) internal view returns (uint256 data) {
    assembly { data := sload(position) }
  }

  function _getTotalShares() internal view returns (uint256) {
    return getStorageUint256(TOTAL_SHARES_POSITION);
  }

  function _getTotalPooledEther() internal view returns (uint256) {
    return totalPooledEther;
  }

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
