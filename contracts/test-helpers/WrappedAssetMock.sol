// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/TransferHelper.sol";
import "../interfaces/wrapped-assets/IWrappedAsset.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WrappedAssetMock
 * @dev Mock contract for wrapped assets, used for testing purposes.
 */
contract WrappedAssetMock is ERC20, IWrappedAsset {

    /// @notice Address of the underlying token.
    address public underlyingToken;

    /// @dev Unique identifier for Unit Protocol wrapped assets.
    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token.
     * @param _underlyingToken Address of the underlying token.
     */
    constructor(address _underlyingToken) ERC20('TestsWA', 'Tests wrapped asset') {
        underlyingToken = _underlyingToken;
    }

    /**
     * @notice Returns the address of the underlying token.
     * @return IERC20 The IERC20 interface of the underlying token.
     */
    function getUnderlyingToken() external view override returns (IERC20) {
        return IERC20(underlyingToken);
    }

    /**
     * @notice Sets a new underlying token address.
     * @param _underlyingToken The address of the new underlying token.
     */
    function setUnderlyingToken(address _underlyingToken) external {
        underlyingToken = _underlyingToken;
    }

    /**
     * @notice Deposits the underlying token and mints the wrapped token to the user.
     * @dev This function should only be callable by the user or trusted contracts.
     * @param _userAddr The address of the user to receive the wrapped tokens.
     * @param _amount The amount of the underlying token to deposit.
     */
    function deposit(address _userAddr, uint256 _amount) external override {
        // no caller check since it is for tests only
        TransferHelper.safeTransferFrom(underlyingToken, _userAddr, address(this), _amount);
        _mint(_userAddr, _amount);
    }

    /**
     * @notice Withdraws the underlying token by burning the wrapped token.
     * @dev This function should only be callable by the user or trusted contracts.
     * @param _userAddr The address of the user to return the underlying tokens to.
     * @param _amount The amount of the wrapped token to burn.
     */
    function withdraw(address _userAddr, uint256 _amount) external override {
        // no caller check since it is for tests only
        _burn(_userAddr, _amount);
        TransferHelper.safeTransfer(underlyingToken, _userAddr, _amount);
    }

    /**
     * @notice Returns the pending reward amount for the user, if rewards are supported.
     * @dev This function always returns 0, as rewards are not implemented in this mock.
     * @param /** _userAddr */ The address of the user to check the pending rewards for.
     * @return uint256 The pending reward amount, which is always 0.
     */
    function pendingReward(address /** _userAddr */) external pure override returns (uint256) {
        return 0;
    }

    /**
     * @notice Claims the pending rewards for the user, if rewards are supported.
     * @dev This function is a no-op, as rewards are not implemented in this mock.
     * @param /** _userAddr */ The address of the user to claim rewards for.
     */
    function claimReward(address /** _userAddr */) external override {}

    /**
     * @notice Moves a position, or part of it, to another user, for example in case of liquidation.
     * @dev This function should only be callable by trusted contracts.
     * @param /** _userAddrFrom */ The address of the user from whom the position is moved.
     * @param /** _userAddrTo */ The address of the user to whom the position is moved.
     * @param /** _amount */ The amount of the position to move.
     */
    function movePosition(address /** _userAddrFrom */, address /** _userAddrTo */, uint256 /** _amount */) external override {}
}