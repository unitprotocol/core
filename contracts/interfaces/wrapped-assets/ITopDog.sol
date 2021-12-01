// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IBoneLocker.sol";
import "./IBoneToken.sol";

/**
 * See https://etherscan.io/address/0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7#code
 */
abstract contract ITopDog  {

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. BONEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that BONEs distribution occurs.
        uint256 accBonePerShare; // Accumulated BONEs per share, times 1e12. See below.
    }

    function bone() external virtual view returns (IBoneToken);
    function boneLocker() external virtual view returns (IBoneLocker);
    PoolInfo[] public poolInfo;
    function poolLength() external virtual view returns (uint256);

    function rewardMintPercent() external virtual view returns (uint256);
    function pendingBone(uint256 _pid, address _user) external virtual view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external virtual;
    function withdraw(uint256 _pid, uint256 _amount) external virtual;
}