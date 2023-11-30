// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWrappedAsset is IERC20 /* IERC20WithOptional */ {

    /* Events */
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionMoved(address indexed userFrom, address indexed userTo, uint256 amount);

    event EmergencyWithdraw(address indexed user, uint256 amount);
    event TokenWithdraw(address indexed user, address token, uint256 amount);

    event FeeChanged(uint256 newFeePercent);
    event FeeReceiverChanged(address newFeeReceiver);
    event AllowedBoneLockerSelectorAdded(address boneLocker, bytes4 selector);
    event AllowedBoneLockerSelectorRemoved(address boneLocker, bytes4 selector);

    /**
     * @notice Returns the underlying token of the wrapped asset
     * @return The underlying IERC20 token
     */
    function getUnderlyingToken() external view returns (IERC20);

    /**
     * @notice Deposits the underlying token and mints the wrapped token to the specified user
     * @param _userAddr The address of the user to receive the wrapped tokens
     * @param _amount The amount of the underlying token to deposit
     */
    function deposit(address _userAddr, uint256 _amount) external;

    /**
     * @notice Withdraws the underlying token by burning the wrapped token
     * @param _userAddr The address of the user to return the underlying tokens to
     * @param _amount The amount of the wrapped token to burn
     */
    function withdraw(address _userAddr, uint256 _amount) external;

    /**
     * @notice Returns the pending reward amount for the user if rewards are supported
     * @param _userAddr The address of the user to check the reward for
     * @return The amount of pending reward
     */
    function pendingReward(address _userAddr) external view returns (uint256);

    /**
     * @notice Claims the pending reward for the user if rewards are supported
     * @param _userAddr The address of the user to claim the reward for
     */
    function claimReward(address _userAddr) external;

    /**
     * @notice Moves a position, or a portion of it, to another user (e.g., in case of liquidation)
     * @param _userAddrFrom The address of the user from whom the position is moved
     * @param _userAddrTo The address of the user to whom the position is moved
     * @param _amount The amount of the position to move
     */
    function movePosition(address _userAddrFrom, address _userAddrTo, uint256 _amount) external;

    /**
     * @notice Checks if an asset is a Unit Protocol wrapped asset
     * @return Returns the keccak256 hash of "UnitProtocolWrappedAsset" if the asset is a wrapped asset
     */
    function isUnitProtocolWrappedAsset() external view returns (bytes32);
}