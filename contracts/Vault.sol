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
    mapping(address => mapping(address => uint)) public oracleType;

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
     * @param asset The address of the main collateral token
     * @param user The owner of a position
     **/
    function update(address asset, address user) public hasVaultAccess {

        // calculate fee using stored stability fee
        uint debtWithFee = getDebt(asset, user);
        tokenDebts[asset] = tokenDebts[asset].sub(debts[asset][user]).add(debtWithFee);
        debts[asset][user] = debtWithFee;

        stabilityFee[asset][user] = parameters.stabilityFee(asset);
        liquidationFee[asset][user] = parameters.liquidationFee(asset);
        lastUpdate[asset][user] = now;
    }

    /**
     * @dev Creates new position for user
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function spawn(address asset, address user, uint _oracleType) external hasVaultAccess {
        oracleType[asset][user] = _oracleType;
    }

    /**
     * @dev Clears unused storage variables
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function destroy(address asset, address user) public hasVaultAccess {
        delete stabilityFee[asset][user];
        delete oracleType[asset][user];
        delete lastUpdate[asset][user];
        delete liquidationFee[asset][user];
    }

    /**
     * @notice Tokens must be pre-approved
     * @dev Adds main collateral to a position
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to deposit
     **/
    function depositMain(address asset, address user, uint amount) external hasVaultAccess {
        collaterals[asset][user] = collaterals[asset][user].add(amount);
        asset.safeTransferFromAndVerify(user, address(this), amount);
    }

    /**
     * @dev Withdraws main collateral from a position
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to withdraw
     **/
    function withdrawMain(address asset, address user, uint amount) external hasVaultAccess {
        collaterals[asset][user] = collaterals[asset][user].sub(amount);
        asset.safeTransferAndVerify(user, amount);
    }

    /**
     * @notice Tokens must be pre-approved
     * @dev Adds COL token to a position
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to deposit
     **/
    function depositCol(address asset, address user, uint amount) external hasVaultAccess {
        colToken[asset][user] = colToken[asset][user].add(amount);
        COL.safeTransferFromAndVerify(user, address(this), amount);
    }

    /**
     * @dev Withdraws COL token from a position
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to withdraw
     **/
    function withdrawCol(address asset, address user, uint amount) external hasVaultAccess {
        COL.safeTransferAndVerify(user, amount);
        colToken[asset][user] = colToken[asset][user].sub(amount);
    }

    /**
     * @dev Increases position's debt and mints USDP token
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of USDP to borrow
     **/
    function borrow(address asset, address user, uint amount) external hasVaultAccess returns(uint) {
        update(asset, user);
        debts[asset][user] = debts[asset][user].add(amount);
        tokenDebts[asset] = tokenDebts[asset].add(amount);

        // check USDP limit for token
        require(tokenDebts[asset] <= parameters.tokenDebtLimit(asset), "USDP: TOKEN_DEBT_LIMIT");

        usdp.mint(user, amount);

        return debts[asset][user];
    }

    /**
     * @dev Decreases position's debt and burns USDP token
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of USDP to repay
     **/
    function repay(address asset, address user, uint amount) external hasVaultAccess returns(uint) {
        uint debt = debts[asset][user];
        uint debtWithFee = getDebt(asset, user);
        debts[asset][user] = debtWithFee.sub(amount);
        tokenDebts[asset] = tokenDebts[asset].sub(amount).add(debtWithFee.sub(debt));
        usdp.burn(user, amount);

        return debts[asset][user];
    }

    /**
     * @dev Deletes position and transfers collateral to liquidation system
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param liquidationSystem The address of an liquidation system
     **/
    function liquidate(address asset, address user, address liquidationSystem) external hasVaultAccess {

        // reverts if oracle type is disabled
        require(parameters.isOracleTypeEnabled(oracleType[asset][user], asset), "USDP: WRONG_ORACLE_TYPE");

        COL.safeTransferAndVerify(liquidationSystem, colToken[asset][user]);
        asset.safeTransferAndVerify(liquidationSystem, collaterals[asset][user]);
        tokenDebts[asset] = tokenDebts[asset].sub(debts[asset][user]);
        delete debts[asset][user];
        delete collaterals[asset][user];
        delete colToken[asset][user];
        destroy(asset, user);
    }

    /**
     * @notice Only manager can call this function
     * @dev Changes broken oracle type to the correct one
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param newOracleType The new type of an oracle
     **/
    function changeOracleType(address asset, address user, uint newOracleType) external onlyManager {
        oracleType[asset][user] = newOracleType;
    }

    /**
     * @dev Calculates the amount of debt based on elapsed time
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     **/
    function getDebt(address asset, address user) public view returns (uint) {
        uint sFeePercent = stabilityFee[asset][user];
        uint amount = debts[asset][user];
        uint secondsPast = now - lastUpdate[asset][user];

        uint fee = amount.mul(sFeePercent).mul(secondsPast).div(365 days).div(FEE_DENOMINATOR);
        return amount.add(fee);
    }
}
