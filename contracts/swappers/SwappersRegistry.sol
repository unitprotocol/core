// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "../interfaces/swappers/ISwappersRegistry.sol";
import "../Auth2.sol";


contract SwappersRegistry is ISwappersRegistry, Auth2 {

    mapping(ISwapper => uint) internal swappersIds;
    ISwapper[] internal swappers;

    constructor(address _vaultParameters) Auth2(_vaultParameters) {}

    function getSwappersLength() external view override returns (uint) {
        return swappers.length;
    }

    function getSwapperId(ISwapper _swapper) external view override returns (uint) {
        return swappersIds[_swapper];
    }

    function getSwapper(uint _id) external view override returns (ISwapper) {
        return swappers[_id];
    }

    function hasSwapper(ISwapper _swapper) external view override returns (bool) {
        if (swappers.length == 0) {
            return false;
        }

        return swappers[ swappersIds[_swapper] ] == _swapper;
    }

    function getSwappers() external view override returns (ISwapper[] memory) {
        return swappers;
    }

    function add(ISwapper _swapper) public onlyManager {
        require(address(_swapper) != address(0), "Unit Protocol: ZERO_ADDRESS");

        swappers.push(_swapper);
        swappersIds[_swapper] = swappers.length - 1;

        emit SwapperAdded(_swapper);
    }

    function remove(ISwapper _swapper) public onlyManager {
        require(address(_swapper) != address(0), "Unit Protocol: ZERO_ADDRESS");

        uint id = swappersIds[_swapper];
        delete swappersIds[_swapper];

        uint lastId = swappers.length - 1;
        if (id != lastId) {
            ISwapper lastSwapper = swappers[lastId];
            swappers[id] = lastSwapper;
            swappersIds[lastSwapper] = id;
        }
        swappers.pop();

        emit SwapperRemoved(_swapper);
    }
}
