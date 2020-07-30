// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.6.6;

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function totalSupply() external view returns (uint256);
}
