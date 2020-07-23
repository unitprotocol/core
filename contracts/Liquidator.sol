// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "./helpers/SafeMath.sol";
import "./Parameters.sol";
import "./Vault.sol";
import "./UniswapOracle.sol";
import "./helpers/ERC20Like.sol";


// interface for interaction with oracles
interface OracleLike {
    function tokenToUsd(address, uint) external view returns(uint);
}

/**
 * @title Liquidator
 * @dev Manages liquidation process
 **/
contract Liquidator {
    using SafeMath for uint;

    // system parameters contract address
    Parameters public parameters;

    // Vault contract
    Vault public vault;

    // uniswap-based oracle contract
    OracleLike public uniswapOracle;

    // COL token address
    address public COL;

    // liquidation system address
    address public liquidationSystem;

    /**
     * @dev Trigger when liquidations are happened
    **/
    event Liquidation(address indexed token, address indexed user);

    /**
     * @param _parameters The address of the system parameters
     * @param _vault The address of the Vault
     * @param _uniswapOracle The address of Uniswap-based Oracle
     * @param _col COL token address
     * @param _liquidationSystem The liquidation system's address
     **/
    constructor(address _parameters, address _vault, address _uniswapOracle, address _col, address _liquidationSystem) public {
        parameters = Parameters(_parameters);
        vault = Vault(_vault);
        uniswapOracle = OracleLike(_uniswapOracle);
        COL = _col;
        liquidationSystem = _liquidationSystem;
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param token The address of the main collateral token of a position
     * @param user The owner of a position
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(address token, address user) public view returns (bool) {
        return getCollateralizationRatio(token, user) <= parameters.liquidationRatio(token);
    }

    /**
     * @dev Determines whether a position is sufficiently collateralized
     * @param token The address of the main collateral token of a position
     * @param user The owner of a position
     * @return boolean value, whether a position is sufficiently collateralized
     **/
    function isSafePosition(address token, address user) public view returns (bool) {
        return getCollateralizationRatio(token, user) >= parameters.initialCollateralRatio(token);
    }

    /**
     * @dev Calculates position's collateral ratio
     * @param token The address of the main collateral token of a position
     * @param user The owner of a position
     * @return collateralization ratio of a position
     **/
    function getCollateralizationRatio(address token, address user) public view returns (uint) {
        uint debt = vault.getDebt(token, user);

        // position is collateralized if there is no debt
        if (debt == 0) return parameters.initialCollateralRatio(token);

        OracleLike _usingOracle;

        // initially, only Uniswap is possible
        if (vault.oracleType(token, user) == 1) {
            _usingOracle = uniswapOracle;
        } else revert("USDP: WRONG_ORACLE_TYPE");

        // USD value of the main collateral
        uint mainCollateralUsd = _usingOracle.tokenToUsd(token, vault.collaterals(token, user));

        // USD value of the COL amount of a position
        uint colTokenUsd = _usingOracle.tokenToUsd(COL, vault.colToken(token, user));

        return mainCollateralUsd.add(colTokenUsd).mul(100).div(debt);
    }

    /**
     * @notice Funds transfers directly to the liquidation system's address
     * @dev Triggers liquidation process
     * @param token The address of the main collateral token of a position
     * @param user The owner of a position
     **/
    function liquidate(address token, address user) external {

        // reverts if a position is safe
        require(isLiquidatablePosition(token, user), "USDP: SAFE_POSITION");

        // sends liquidation command to the Vault
        vault.liquidate(token, user, liquidationSystem);

        // fire an liquidation event
        emit Liquidation(token, user);
    }
}
