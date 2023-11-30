// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../interfaces/swappers/ISwapper.sol";
import "../interfaces/swappers/ISwappersRegistry.sol";
import "../Auth2.sol";

/**
 * @title SwappersRegistry
 * @dev Contract to manage a registry of swappers for Unit Protocol.
 * Inherits from ISwappersRegistry and Auth2 for swapper interface and authorization respectively.
 */
contract SwappersRegistry is ISwappersRegistry, Auth2 {

    struct SwapperInfo {
        uint240 id;
        bool exists;
    }

    mapping(ISwapper => SwapperInfo) internal swappersInfo;
    ISwapper[] internal swappers;

    /**
     * @dev Initializes the contract by setting vault parameters and invoking Auth2 constructor.
     * @param _vaultParameters The address of the vault parameters contract.
     */
    constructor(address _vaultParameters) Auth2(_vaultParameters) {}

    /**
     * @dev Returns the number of swappers registered.
     * @return The number of registered swappers.
     */
    function getSwappersLength() external view override returns (uint) {
        return swappers.length;
    }

    /**
     * @dev Retrieves the ID of a specific swapper.
     * @param _swapper The address of the swapper to query.
     * @return The ID of the swapper.
     * @notice Throws if the swapper does not exist.
     */
    function getSwapperId(ISwapper _swapper) external view override returns (uint) {
        require(hasSwapper(_swapper), "Unit Protocol Swappers: SWAPPER_IS_NOT_EXIST");

        return uint(swappersInfo[_swapper].id);
    }

    /**
     * @dev Retrieves the swapper address by ID.
     * @param _id The ID of the swapper to query.
     * @return The address of the swapper with the given ID.
     */
    function getSwapper(uint _id) external view override returns (ISwapper) {
        return swappers[_id];
    }

    /**
     * @dev Checks if a swapper is registered.
     * @param _swapper The address of the swapper to check.
     * @return True if the swapper exists, false otherwise.
     */
    function hasSwapper(ISwapper _swapper) public view override returns (bool) {
        return swappersInfo[_swapper].exists;
    }

    /**
     * @dev Retrieves the list of all registered swappers.
     * @return An array of addresses of the registered swappers.
     */
    function getSwappers() external view override returns (ISwapper[] memory) {
        return swappers;
    }

    /**
     * @dev Registers a new swapper.
     * @param _swapper The address of the swapper to register.
     * @notice Only callable by the manager role.
     * @notice Throws if the swapper address is zero or if the swapper is already registered.
     */
    function add(ISwapper _swapper) public onlyManager {
        require(address(_swapper) != address(0), "Unit Protocol Swappers: ZERO_ADDRESS");
        require(!hasSwapper(_swapper), "Unit Protocol Swappers: SWAPPER_ALREADY_EXISTS");

        swappers.push(_swapper);
        swappersInfo[_swapper] = SwapperInfo(uint240(swappers.length - 1), true);

        emit SwapperAdded(_swapper);
    }

    /**
     * @dev Unregisters a swapper.
     * @param _swapper The address of the swapper to unregister.
     * @notice Only callable by the manager role.
     * @notice Throws if the swapper address is zero or if the swapper does not exist.
     */
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