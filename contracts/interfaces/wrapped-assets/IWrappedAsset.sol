// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../IERC20WithOptional.sol";

interface IWrappedAsset is IERC20WithOptional {

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    /**
     * @notice Get underlying token
     */
    function getUnderlyingToken() external view returns (IERC20);

    /**
     * @notice deposit underlying token and send wrapped token to user
     */
    function deposit(address _userAddr, uint256 _amount) external;

    /**
     * @notice get wrapped token and return underlying
     */
    function withdraw(address _userAddr, uint256 _amount) external;

    /**
     * @notice get pending reward amount for user if reward is supported
     */
    function pendingReward(address _userAddr) external view returns (uint256);

    /**
     * @notice claim pending reward for caller if reward is supported
     */
    function claimReward() external;
}
