// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IBoneLocker.sol";
import "./IBoneToken.sol";

/**
 * @title ITopDog
 * @dev Interface for interacting with the TopDog contract.
 * See https://etherscan.io/address/0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7#code
 */
interface ITopDog  {

    /**
     * @dev Returns the address of the BONE token contract.
     * @return IBoneToken Address of the BONE token contract.
     */
    function bone() external view returns (IBoneToken);

    /**
     * @dev Returns the address of the BoneLocker contract.
     * @return IBoneLocker Address of the BoneLocker contract.
     */
    function boneLocker() external view returns (IBoneLocker);

    /**
     * @dev Provides information about a specific liquidity pool.
     * @param _pid The index of the pool.
     * @return IERC20 The address of the pool's token contract.
     * @return uint256 The allocation point assigned to the pool.
     * @return uint256 The last block number that BONE distribution occurs.
     * @return uint256 The accumulated BONE per share.
     */
    function poolInfo(uint256 _pid) external view returns (IERC20, uint256, uint256, uint256);

    /**
     * @dev Returns the total number of liquidity pools.
     * @return uint256 The total number of liquidity pools.
     */
    function poolLength() external view returns (uint256);

    /**
     * @dev Provides information about a user's position in a specific pool.
     * @param _pid The index of the pool.
     * @param _user The address of the user.
     * @return uint256 The amount of pool tokens the user has provided.
     * @return uint256 The reward debt of the user.
     */
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    /**
     * @dev Returns the percentage of BONE tokens minted as rewards.
     * @return uint256 The reward mint percent.
     */
    function rewardMintPercent() external view returns (uint256);

    /**
     * @dev Calculates the pending BONE rewards for a user in a given pool.
     * @param _pid The index of the pool.
     * @param _user The address of the user.
     * @return uint256 The amount of pending BONE rewards.
     */
    function pendingBone(uint256 _pid, address _user) external view returns (uint256);

    /**
     * @notice Deposit pool tokens to TopDog for BONE allocation.
     * @dev Deposits tokens into a specific pool for BONE allocation.
     * @param _pid The index of the pool.
     * @param _amount The amount of pool tokens to deposit.
     */
    function deposit(uint256 _pid, uint256 _amount) external;

    /**
     * @notice Withdraw pool tokens from TopDog.
     * @dev Withdraws pool tokens from a specific pool.
     * @param _pid The index of the pool.
     * @param _amount The amount of pool tokens to withdraw.
     */
    function withdraw(uint256 _pid, uint256 _amount) external;

    /**
     * @notice Perform an emergency withdrawal of pool tokens from TopDog.
     * @dev Withdraws all pool tokens from a specific pool without caring about rewards. 
     * @param _pid The index of the pool.
     */
    function emergencyWithdraw(uint256 _pid) external;
}