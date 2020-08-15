// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;

import "./helpers/SafeMath.sol";
import "./helpers/USDPLib.sol";
import "./Parameters.sol";
import "./helpers/ERC20SafeTransfer.sol";
import "./USDP.sol";


/**
 * @title Vault
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @notice Vault is the core of USD ThePay.cash Stablecoin distribution system
 * @notice Vault stores and manages collateral funds of all positions and counts debts
 * @notice Only Vault can manage supply of USDP token
 * @notice Vault will not be changed/upgraded after initial deployment for the current stablecoin version
 **/
contract Vault is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    // COL token address
    address public COL;

    uint public constant FEE_DENOMINATOR = 100000;

    // USDP token address
    USDP public usdp;

    // collaterals whitelist
    mapping(address => mapping(address => uint)) public collaterals;

    // COL token collaterals
    mapping(address => mapping(address => uint)) public colToken;

    // user debts
    mapping(address => mapping(address => uint)) internal debts;

    // debts of tokens
    mapping(address => uint) public tokenDebts;

    // stability fee pinned to each position
    mapping(address => mapping(address => uint)) public stabilityFee;

    // liquidation fee pinned to each position
    mapping(address => mapping(address => uint)) public liquidationFee;

    // type of using oracle pinned for each position
    mapping(address => mapping(address => USDPLib.Oracle)) public oracleType;

    // timestamp of the last update
    mapping(address => mapping(address => uint)) public lastUpdate;

    /**
     * @param _parameters The address of the system parameters
     * @param _col COL token address
     * @param _usdp USDP token address
     **/
    constructor(address _parameters, address _col, USDP _usdp) public Auth(_parameters) {
        COL = _col;
        usdp = _usdp;
    }

    /**
     * @dev Updates parameters of the position to the current ones
     * @param token The address of the main collateral token
     * @param user The owner of a position
     **/
    function update(address token, address user) public hasVaultAccess {

        // calculate fee using stored stability fee
        uint debtWithFee = getDebt(token, user);
        tokenDebts[token] = tokenDebts[token].sub(debts[token][user]).add(debtWithFee);
        debts[token][user] = debtWithFee;

        stabilityFee[token][user] = parameters.stabilityFee(token);
        liquidationFee[token][user] = parameters.liquidationFee(token);
        lastUpdate[token][user] = now;
    }

    /**
     * @dev Creates new position for user
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function spawn(address token, address user, USDPLib.Oracle _oracleType) external hasVaultAccess {
        oracleType[token][user] = _oracleType;
    }

    /**
     * @dev Clears unused storage variables
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function destroy(address token, address user) public hasVaultAccess {
        delete stabilityFee[token][user];
        delete oracleType[token][user];
        delete lastUpdate[token][user];
        delete liquidationFee[token][user];
    }

    /**
     * @notice Tokens must be pre-approved
     * @dev Adds main collateral to a position
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to deposit
     **/
    function depositMain(address token, address user, uint amount) external hasVaultAccess {
        collaterals[token][user] = collaterals[token][user].add(amount);
        token.safeTransferFromAndVerify(user, address(this), amount);
    }

    /**
     * @dev Withdraws main collateral from a position
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to withdraw
     **/
    function withdrawMain(address token, address user, uint amount) external hasVaultAccess {
        collaterals[token][user] = collaterals[token][user].sub(amount);
        token.safeTransferAndVerify(user, amount);
    }

    /**
     * @notice Tokens must be pre-approved
     * @dev Adds COL token to a position
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to deposit
     **/
    function depositCol(address token, address user, uint amount) external hasVaultAccess {
        colToken[token][user] = colToken[token][user].add(amount);
        COL.safeTransferFromAndVerify(user, address(this), amount);
    }

    /**
     * @dev Withdraws COL token from a position
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to withdraw
     **/
    function withdrawCol(address token, address user, uint amount) external hasVaultAccess {
        COL.safeTransferAndVerify(user, amount);
        colToken[token][user] = colToken[token][user].sub(amount);
    }

    /**
     * @dev Increases position's debt and mints USDP token
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of USDP to borrow
     **/
    function borrow(address token, address user, uint amount) external hasVaultAccess returns(uint) {
        update(token, user);
        debts[token][user] = debts[token][user].add(amount);
        tokenDebts[token] = tokenDebts[token].add(amount);

        // check USDP limit for token
        require(tokenDebts[token] <= parameters.tokenDebtLimit(token), "USDP: TOKEN_DEBT_LIMIT");

        usdp.mint(user, amount);

        return debts[token][user];
    }

    /**
     * @dev Decreases position's debt and burns USDP token
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of USDP to repay
     **/
    function repay(address token, address user, uint amount) external hasVaultAccess returns(uint) {
        uint debt = debts[token][user];
        uint debtWithFee = getDebt(token, user);
        debts[token][user] = debtWithFee.sub(amount);
        tokenDebts[token] = tokenDebts[token].sub(amount).add(debtWithFee.sub(debt));
        usdp.burn(user, amount);

        return debts[token][user];
    }

    /**
     * @dev Deletes position and transfers collateral to liquidation system
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param liquidationSystem The address of an liquidation system
     **/
    function liquidate(address token, address user, address liquidationSystem) external hasVaultAccess {

        // reverts if oracle type is disabled
        require(parameters.isOracleTypeEnabled(oracleType[token][user], token), "USDP: WRONG_ORACLE_TYPE");

        COL.safeTransferAndVerify(liquidationSystem, colToken[token][user]);
        token.safeTransferAndVerify(liquidationSystem, collaterals[token][user]);
        tokenDebts[token] = tokenDebts[token].sub(debts[token][user]);
        delete debts[token][user];
        delete collaterals[token][user];
        delete colToken[token][user];
        destroy(token, user);
    }

    /**
     * @notice Only manager can call this function
     * @dev Changes broken oracle type to the correct one
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     * @param newOracleType The new type of an oracle
     **/
    function changeOracleType(address token, address user, USDPLib.Oracle newOracleType) external onlyManager {
        oracleType[token][user] = newOracleType;
    }

    /**
     * @dev Calculates the amount of debt based on elapsed time
     * @param token The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function getDebt(address token, address user) public view returns (uint) {
        uint sFeePercent = stabilityFee[token][user];
        uint amount = debts[token][user];
        uint secondsPast = now - lastUpdate[token][user];

        uint fee = amount.mul(sFeePercent).mul(secondsPast).div(365 days).div(FEE_DENOMINATOR);
        return amount.add(fee);
    }
}
