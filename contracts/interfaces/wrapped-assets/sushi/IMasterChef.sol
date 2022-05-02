// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;


import "./ISushiToken.sol";

interface IMasterChef {
    function sushi() external view returns (ISushiToken);
    function poolInfo(uint256) external view returns (IERC20, uint256, uint256, uint256);
    function poolLength() external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256, uint256);

    function pendingSushi(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

}