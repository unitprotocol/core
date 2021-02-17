// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;

import "../Vault.sol";
import "../vault-managers/VaultManagerParameters.sol";
import "../helpers/ReentrancyGuard.sol";


/**
 * @title LiquidationTriggerSimple
 * @dev Manages triggering of liquidation process
 **/
abstract contract LiquidationTriggerBase {
    using SafeMath for uint;

    uint public constant DENOMINATOR_1E5 = 1e5;
    uint public constant DENOMINATOR_1E2 = 1e2;

    // vault manager parameters contract
    VaultManagerParameters public immutable vaultManagerParameters;

    uint public immutable oracleType;

    // Vault contract
    Vault public immutable vault;

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed token, address indexed user);

    /**
     * @param _vaultManagerParameters The address of the contract with vault manager parameters
     * @param _oracleType The id of the oracle type
     **/
    constructor(address _vaultManagerParameters, uint _oracleType) internal {
        vaultManagerParameters = VaultManagerParameters(_vaultManagerParameters);
        vault = Vault(VaultManagerParameters(_vaultManagerParameters).vaultParameters().vault());
        oracleType = _oracleType;
    }

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function triggerLiquidation(address asset, address user) external virtual {}

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the main collateral token of a position
     * @param user The owner of a position
     * @param collateralUsdValue USD value of the collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address user,
        uint collateralUsdValue
    ) public virtual view returns (bool);

    /**
     * @dev Calculates position's utilization ratio
     * @param collateralUsdValue USD value of collateral
     * @param debt USDP borrowed
     * @return utilization ratio of a position
     **/
    function UR(uint collateralUsdValue, uint debt) public virtual pure returns (uint);
}
