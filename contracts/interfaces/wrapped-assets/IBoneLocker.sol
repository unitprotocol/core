// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title Interface for BoneToken Locker Contract
 * @dev This interface defines the functions for locking BoneTokens and claiming them after a locking period.
 */
interface IBoneLocker {

    /**
     * @dev Retrieves lock information for a user by index.
     * @param user The address of the user whose lock info is being queried.
     * @param index The index of the user's lock info to retrieve.
     * @return amount The amount of tokens locked.
     * @return timestamp The timestamp when the tokens were locked.
     * @return isDev Indicates if the locked tokens belong to a developer.
     */
    function lockInfoByUser(address user, uint256 index) external view returns (uint256 amount, uint256 timestamp, bool isDev);

    /**
     * @dev Retrieves the current locking period.
     * @return The duration of the locking period in seconds.
     */
    function lockingPeriod() external view returns (uint256);

    /**
     * @dev Claims all tokens locked for a user after the locking period has ended.
     * @param r The round or batch number for claiming.
     * @param user The address of the user whose tokens are being claimed.
     */
    function claimAllForUser(uint256 r, address user) external;

    /**
     * @dev Claims all tokens locked by the caller after the locking period has ended.
     * @param r The round or batch number for claiming.
     */
    function claimAll(uint256 r) external;

    /**
     * @dev Retrieves the claimable amount of tokens for a user.
     * @param _user The address of the user whose claimable amount is being queried.
     * @return The amount of tokens that the user can currently claim.
     */
    function getClaimableAmount(address _user) external view returns(uint256);

    /**
     * @dev Retrieves the left and right counters for a user's lock info.
     * @param _user The address of the user whose counters are being queried.
     * @return leftCounter The index counter up to which the user's lock info has been iterated.
     * @return rightCounter The length of the user's lockInfo array, indicating the total number of locks.
     */
    function getLeftRightCounters(address _user) external view returns(uint256 leftCounter, uint256 rightCounter);

    /**
     * @dev Locks a specified amount of tokens for a user.
     * @param _holder The address of the user for whom the tokens are being locked.
     * @param _amount The amount of tokens to lock.
     * @param _isDev Indicates if the locked tokens belong to a developer.
     */
    function lock(address _holder, uint256 _amount, bool _isDev) external;

    /**
     * @dev Sets a new locking period.
     * @param _newLockingPeriod The new locking period duration in seconds.
     * @param _newDevLockingPeriod The new locking period duration for developers in seconds.
     */
    function setLockingPeriod(uint256 _newLockingPeriod, uint256 _newDevLockingPeriod) external;

    /**
     * @dev Allows the owner to withdraw all tokens from the contract in case of an emergency.
     * @param _to The address where the withdrawn tokens will be transferred.
     */
    function emergencyWithdrawOwner(address _to) external;
}