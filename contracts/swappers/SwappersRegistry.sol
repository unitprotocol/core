// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "../interfaces/swappers/ISwappersRegistry.sol";
import "../Auth2.sol";


contract SwappersRegistry is ISwappersRegistry, Auth2 {

    struct SwapperInfo {
        uint240 id;
        bool exists;
    }

    mapping(ISwapper => SwapperInfo) internal swappersInfo;
    ISwapper[] internal swappers;

    constructor(address _vaultParameters) Auth2(_vaultParameters) {}

    function getSwappersLength() external view override returns (uint) {
        return swappers.length;
    }

    function getSwapperId(ISwapper _swapper) external view override returns (uint) {
        require(hasSwapper(_swapper), "Unit Protocol Swappers: SWAPPER_IS_NOT_EXIST");

        return uint(swappersInfo[_swapper].id);
    }

    function getSwapper(uint _id) external view override returns (ISwapper) {
        return swappers[_id];
    }

    function hasSwapper(ISwapper _swapper) public view override returns (bool) {
        return swappersInfo[_swapper].exists;
    }

    function getSwappers() external view override returns (ISwapper[] memory) {
        return swappers;
    }

    function add(ISwapper _swapper) public onlyManager {
        require(address(_swapper) != address(0), "Unit Protocol Swappers: ZERO_ADDRESS");
        require(!hasSwapper(_swapper), "Unit Protocol Swappers: SWAPPER_ALREADY_EXISTS");

        swappers.push(_swapper);
        swappersInfo[_swapper] = SwapperInfo(uint240(swappers.length - 1), true);

        emit SwapperAdded(_swapper);
    }

    function remove(ISwapper _swapper) public onlyManager {
        require(address(_swapper) != address(0), "Unit Protocol Swappers: ZERO_ADDRESS");
        require(hasSwapper(_swapper), "Unit Protocol Swappers: SWAPPER_IS_NOT_EXIST");

        uint id = uint(swappersInfo[_swapper].id);
        delete swappersInfo[_swapper];

        uint lastId = swappers.length - 1;
        if (id != lastId) {
            ISwapper lastSwapper = swappers[lastId];
            swappers[id] = lastSwapper;
            swappersInfo[lastSwapper] = SwapperInfo(uint240(id), true);
        }
        swappers.pop();

        emit SwapperRemoved(_swapper);
    }
}
