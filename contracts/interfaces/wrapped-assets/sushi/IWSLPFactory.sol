// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

interface IWSLPFactory {
    struct FeeInfo {
        address feeReceiver;
        uint8 feePercent;
    }

    event FeeChanged(address feeReceiver, uint8 feePercent);
    event WrappedLpDeployed(address wrappedLp, uint rewardDistributorPoolId);

    function feeInfo() external view returns (address feeReceiver, uint8 feePercent);
    function setFee(address _feeReceiver, uint8 _feePercent) external;
    function deploy(uint256 _rewardDistributorPoolId) external returns (address wrappedLp);
}