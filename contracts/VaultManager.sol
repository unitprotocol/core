// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./helpers/ERC20SafeTransfer.sol";
import "./vault.sol";
import "./parameters.sol";
import "./uniswap_oracle.sol";
import "./liquidator.sol";
import "./helpers/SafeMath.sol";


contract ERC20Join is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    Vault public vault;
    address public COL;
    OracleLike public uniswapOracle;
    Liquidator public liquidator;

    event Spawn(address indexed collateral, address indexed user, uint oracleType);
    event Update(address indexed collateral, address indexed user);

    constructor(address _vault, address _liquidator, address _parameters, address _uniswapOracle, address _col) Auth(_parameters) public {
        vault = Vault(_vault);
        liquidator = Liquidator(_liquidator);
        uniswapOracle = OracleLike(_uniswapOracle);
        COL = _col;
    }

    /**
      * @notice Cannot be used for spawned positions
      * @notice Token using as main collateral must be whitelisted
      * @notice Depositing tokens must be pre-approved to vault address
      * @dev Spawns new positions 
      * @dev Adds collaterals to non-spawned positions
      * @notice position actually spawns when usdpAmount > 0
      * @param token The address of token using as main collateral
      * @param mainAmount The amount of main collateral to deposit
      * @param colAmount The amount of COL token to deposit
      * @param usdpAmount The amount of USDP token to borrow
      * @param oracleType The type of an oracle. Initially only Uniswap possible (1)
      **/
    function spawn(address token, uint mainAmount, uint colAmount, uint usdpAmount, uint oracleType) external {
        // check whether the position is spawned
        require(vault.getDebt(token, msg.sender) == 0, "USDP: SPAWNED_POSITION");
        
        // USDP minting triggers the spawn of a position
        if (usdpAmount > 0) {
            // initially only Uniswap possible
            require(oracleType == 1, "USDP: WRONG_ORACLE_TYPE");
            vault.spawn(token, msg.sender, oracleType);
        
            emit Spawn(token, msg.sender, oracleType);
        }

        _join(token, mainAmount, colAmount, usdpAmount);
    }

    /**
     * @notice Position should be spawned (USDP minted) to call this method
     * @notice Depositing tokens must be pre-approved to vault address
     * @notice Token using as main collateral must be whitelisted
     * @dev Deposits collaterals to spawned positions
     * @dev Borrows USDP
     * @param token The address of token using as main collateral
     * @param mainAmount The amount of main collateral to deposit
     * @param colAmount The amount of COL token to deposit
     * @param usdpAmount The amount of USDP token to borrow
     **/
    function join(address token, uint mainAmount, uint colAmount, uint usdpAmount) external {

        require(vault.getDebt(token, msg.sender) > 0);

        _join(token, mainAmount, colAmount, usdpAmount);
        
        // USDP minting triggers the update of a position
        if (usdpAmount > 0)
            _updatePosition(token);
    }

    function _join(address token, uint mainAmount, uint colAmount, uint usdpAmount) internal {
        require(parameters.isCollateral(token), "USDP: WRONG_COLLATERAL");
        require(mainAmount.add(colAmount) > 0 || usdpAmount > 0, "USDP: USELESS_TX");
        uint usdpDebt = vault.getDebt(token, msg.sender);

        if (usdpAmount > 0) {
            uint newColUsd = uniswapOracle.tokenToUsd(COL, vault.colToken(token, msg.sender).add(colAmount));
            
            // required part of COL token must be presented in collateral in order to mint USDP
            require(newColUsd.mul(100).div(usdpDebt.add(usdpAmount)) >= parameters.requiredColPercent(), "USDP: NOT_ENOUGH_COL_TOKEN_PART");

            // mint USDP to user
            vault.addDebt(token, msg.sender, usdpAmount);
        }

        if (mainAmount > 0)
            vault.addMainCollateral(token, msg.sender, mainAmount);

        if (colAmount > 0)
            vault.addColToken(token, msg.sender, colAmount);

        // revert if the position is undercollateralized
        require(liquidator.isSafePosition(token, msg.sender), "USDP: UNDERCOLLATERALIZED_POSITION");
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @notice Token approwal is NOT needed
      * @dev Repays total debt and withdraws collaterals
      * @param token The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      **/
    function repayAll(address token, uint mainAmount, uint colAmount) external {
        uint usdpAmount = vault.getDebt(token, msg.sender);
        exit(token, mainAmount, colAmount, usdpAmount);
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral
      * @dev Repays specified amount of debt
      * @param token The address of token using as main collateral
      * @param mainAmount The amount of main collateral token to withdraw
      * @param colAmount The amount of COL token to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function exit(address token, uint mainAmount, uint colAmount, uint usdpAmount) public {
        require(mainAmount.add(colAmount) > 0 || usdpAmount > 0, "USDP: USELESS_TX");

        if (mainAmount > 0)
            // withdraws main collateral to user address
            vault.subMainCollateral(token, msg.sender, mainAmount);

        if (colAmount > 0)
            // withdraws COL tokens to user address
            vault.subColToken(token, msg.sender, colAmount);

         if (usdpAmount > 0)
            // burns USDP from user address
             vault.subDebt(token, msg.sender, usdpAmount);

        // revert if the position is undercollateralized
        require(liquidator.isSafePosition(token, msg.sender), "USDP: UNDERCOLLATERALIZED_POSITION");

        if (vault.getDebt(token, msg.sender) == 0)
            // clear unused storage
            vault.destroy(token, msg.sender);
        else if (mainAmount > 0 || colAmount > 0)
            _updatePosition(token);
    }


    // update position parameters to the current ones
    function _updatePosition(address token) internal {
        vault.update(token, msg.sender);
        emit Update(token, msg.sender);
    }
}