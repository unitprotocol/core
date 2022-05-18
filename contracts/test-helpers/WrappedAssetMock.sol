// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/TransferHelper.sol";
import "../interfaces/wrapped-assets/IWrappedAsset.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SwapperMock
 * @dev Used in tests
 **/
contract WrappedAssetMock is ERC20, IWrappedAsset {

    address public underlyingToken;
    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    constructor(address _underlyingToken) ERC20('TestsWA', 'Tests wrapped asset') {
        underlyingToken = _underlyingToken;
    }

    function getUnderlyingToken() external view override returns (IERC20) {
        return IERC20(underlyingToken);
    }

    function setUnderlyingToken(address _underlyingToken) external {
        underlyingToken = _underlyingToken;
    }

    /**
     * @notice deposit underlying token and send wrapped token to user
     * @dev Important! Only user or trusted contracts must be able to call this method
     */
    function deposit(address _userAddr, uint256 _amount) external override {
        // no caller check since it is for tests only
        TransferHelper.safeTransferFrom(underlyingToken, _userAddr, address(this), _amount);
        _mint(_userAddr, _amount);
    }

    /**
     * @notice get wrapped token and return underlying
     * @dev Important! Only user or trusted contracts must be able to call this method
     */
    function withdraw(address _userAddr, uint256 _amount) external override {
        // no caller check since it is for tests only
        _burn(_userAddr, _amount);
        TransferHelper.safeTransfer(underlyingToken, _userAddr, _amount);
    }

    /**
     * @notice get pending reward amount for user if reward is supported
     */
    function pendingReward(address /** _userAddr */) external pure override returns (uint256) {
        return 0;
    }

    /**
     * @notice claim pending reward for user if reward is supported
     */
    function claimReward(address /** _userAddr */) external override {}

    /**
     * @notice Manually move position (or its part) to another user (for example in case of liquidation)
     * @dev Important! Only trusted contracts must be able to call this method
     */
    function movePosition(address /** _userAddrFrom */, address /** _userAddrTo */, uint256 /** _amount */) external override {}
}
