// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IBoneLocker.sol";
import "./IBoneToken.sol";

/**
 * See https://etherscan.io/address/0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7#code
 */
interface ITopDog  {

    function bone() external view returns (IBoneToken);
    function boneLocker() external view returns (IBoneLocker);
    function poolInfo(uint256) external view returns (IERC20, uint256, uint256, uint256);
    function poolLength() external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256, uint256);

    function rewardMintPercent() external view returns (uint256);
    function pendingBone(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;
}