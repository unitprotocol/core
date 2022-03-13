// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @dev BoneToken locker contract interface
 */
interface IBoneLocker {

    function lockInfoByUser(address, uint256) external view returns (uint256, uint256, bool);

    function lockingPeriod() external view returns (uint256);

    // function to claim all the tokens locked for a user, after the locking period
    function claimAllForUser(uint256 r, address user) external;

    // function to claim all the tokens locked by user, after the locking period
    function claimAll(uint256 r) external;

    // function to get claimable amount for any user
    function getClaimableAmount(address _user) external view returns(uint256);

    // get the left and right headers for a user, left header is the index counter till which we have already iterated, right header is basically the length of user's lockInfo array
    function getLeftRightCounters(address _user) external view returns(uint256, uint256);

    function lock(address _holder, uint256 _amount, bool _isDev) external;
    function setLockingPeriod(uint256 _newLockingPeriod, uint256 _newDevLockingPeriod) external;
    function emergencyWithdrawOwner(address _to) external;
}