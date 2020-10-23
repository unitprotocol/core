// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.6.8;

import "./helpers/SafeMath.sol";
import "./Parameters.sol";
import "./helpers/ERC20SafeTransfer.sol";
import "./USDP.sol";
import "./test-helpers/WETH.sol";


interface LiquidationSystem{
    function liquidate(
        address asset,
        address user,
        uint mainAmount,
        uint colAmount,
        uint debt,
        uint liquidationFee
    ) external;
}

/**
 * @title Vault
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @notice Vault is the core of Unit Protocol USDP Stablecoin system
 * @notice Vault stores and manages collateral funds of all positions and counts debts
 * @notice Only Vault can manage supply of USDP token
 * @notice Vault will not be changed/upgraded after initial deployment for the current stablecoin version
 **/
contract Vault is Auth {
    using ERC20SafeTransfer for address;
    using SafeMath for uint;

    // COL token address
    address public col;

    // WETH token address
    address payable public weth;

    uint public constant STABILITY_FEE_DENOMINATOR = 100000;

    uint public constant LIQUIDATION_FEE_DENOMINATOR = 100;

    bool public canReceiveEth = false;

    // USDP token address
    USDP public usdp;

    // collaterals whitelist
    mapping(address => mapping(address => uint)) public collaterals;

    // COL token collaterals
    mapping(address => mapping(address => uint)) public colToken;

    // user debts
    mapping(address => mapping(address => uint)) public debts;

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
    constructor(address _parameters, address _col, USDP _usdp, address payable _weth) public Auth(_parameters) {
        col = _col;
        usdp = _usdp;
        weth = _weth;
    }

    receive() external payable {
        require(canReceiveEth, "Contract does not accept donations");
    }

    /**
     * @dev Updates parameters of the position to the current ones
     * @param asset The address of the main collateral token
     * @param user The owner of a position
     **/
    function update(address asset, address user) public hasVaultAccess {

        // calculate fee using stored stability fee
        uint debtWithFee = getTotalDebt(asset, user);
        tokenDebts[asset] = tokenDebts[asset].sub(debts[asset][user]).add(debtWithFee);
        debts[asset][user] = debtWithFee;

        stabilityFee[asset][user] = parameters.stabilityFee(asset);
        liquidationFee[asset][user] = parameters.liquidationFee(asset);
        lastUpdate[asset][user] = block.timestamp;
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
     * @dev Converts ETH to WETH and adds main collateral to a position
     * @param user The address of a position's owner
     **/
    function depositEth(address user) external payable {
        WETH(weth).deposit{value: msg.value}();
        collaterals[weth][user] = collaterals[weth][user].add(msg.value);
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
     * @dev Withdraws WETH collateral from a position converting WETH to ETH
     * @param user The address of a position's owner
     * @param amount The amount of ETH to withdraw
     **/
    function withdrawEth(address payable user, uint amount) external hasVaultAccess {
        collaterals[weth][user] = collaterals[weth][user].sub(amount);

        canReceiveEth = true;
        WETH(weth).withdraw(amount);
        canReceiveEth = false;

        user.transfer(amount);
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
        col.safeTransferFromAndVerify(user, address(this), amount);
    }

    /**
     * @dev Withdraws COL token from a position
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The amount of tokens to withdraw
     **/
    function withdrawCol(address asset, address user, uint amount) external hasVaultAccess {
        colToken[asset][user] = colToken[asset][user].sub(amount);
        col.safeTransferAndVerify(user, amount);
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
     * @return updated debt of a position
     **/
    function repay(address asset, address user, uint amount) external hasVaultAccess returns(uint) {
        uint debt = debts[asset][user];
        debts[asset][user] = debt.sub(amount);
        tokenDebts[asset] = tokenDebts[asset].sub(amount);
        usdp.burn(user, amount);

        return debts[asset][user];
    }

    /**
     * @dev Transfers fee to foundation
     * @param asset The address of the fee asset
     * @param user The address to transfer funds from
     * @param amount The amount of asset to transfer
     **/
    function chargeFee(address asset, address user, uint amount) external hasVaultAccess {
        if (amount != 0) {
            asset.safeTransferFromAndVerify(user, parameters.foundation(), amount);
        }
    }

    /**
     * @dev Deletes position and transfers collateral to liquidation system
     * @param asset The address of the main collateral token
     * @param positionOwner The address of a position's owner
     * @param liquidator The liquidator address
     * @param usdCollateralValue The total USD value of liquidation collateral
     **/
    function liquidate(
        address asset,
        address positionOwner,
        address liquidator,
        uint usdCollateralValue
    )
        external
        hasVaultAccess
    {
        // reverts if oracle type is disabled
        require(parameters.isOracleTypeEnabled(oracleType[asset][positionOwner], asset), "USDP: WRONG_ORACLE_TYPE");

        uint debt = debts[asset][positionOwner];
        uint assetAmount = collaterals[asset][positionOwner];
        uint colAmount = colToken[asset][positionOwner];

        uint totalDebt = getTotalDebt(asset, positionOwner);
        uint debtWithPenalty = totalDebt.add(totalDebt.mul(parameters.liquidationFee(asset)).div(LIQUIDATION_FEE_DENOMINATOR));

        tokenDebts[asset] = tokenDebts[asset].sub(debt);

        delete debts[asset][positionOwner];
        delete collaterals[asset][positionOwner];
        delete colToken[asset][positionOwner];
        destroy(asset, positionOwner);

        uint colToLiquidator;
        uint assetToLiquidator;

        if (usdCollateralValue > debtWithPenalty) {
            colToLiquidator = colAmount.mul(debtWithPenalty).div(usdCollateralValue);
            assetToLiquidator = assetAmount.mul(debtWithPenalty).div(usdCollateralValue);

            col.safeTransferAndVerify(positionOwner, colAmount.sub(colToLiquidator));
            asset.safeTransferAndVerify(positionOwner, assetAmount.sub(assetToLiquidator));
        } else {
            colToLiquidator = colAmount;
            assetToLiquidator = assetAmount;
        }

        usdp.burn(liquidator, debt);

        if (totalDebt > debt) {
            address(usdp).safeTransferFromAndVerify(liquidator, parameters.foundation(), totalDebt.sub(debt));
        }

        col.safeTransferAndVerify(liquidator, colToLiquidator);
        asset.safeTransferAndVerify(liquidator, assetToLiquidator);
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

    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size != 0;
    }

    /**
     * @dev Calculates the total amount of position's debt based on elapsed time
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @return user debt of a position plus accumulated fee
     **/
    function getTotalDebt(address asset, address user) public view returns (uint) {
        uint debt = debts[asset][user];
        uint fee = calculateFee(asset, user, debt);
        return debt.add(fee);
    }

    /**
     * @dev Calculates the amount of fee based on elapsed time and repayment amount
     * @param asset The address of the main collateral token
     * @param user The address of a position's owner
     * @param amount The repayment amount
     * @return fee amount
     **/
    function calculateFee(address asset, address user, uint amount) public view returns (uint) {
        uint sFeePercent = stabilityFee[asset][user];
        uint timePast = block.timestamp.sub(lastUpdate[asset][user]);

        return amount.mul(sFeePercent).mul(timePast).div(365 days).div(STABILITY_FEE_DENOMINATOR);
    }
}
