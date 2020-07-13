// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "./helpers/ERC20Like.sol";


// Manages USDP's system access
contract Auth {

    // address of the the contract with parameters
    Parameters public parameters;

    constructor(address _parameters) public {
        parameters = Parameters(_parameters);
    }

    // ensures tx's sender is a manager
    modifier onlyManager() {
        require(parameters.isManager(msg.sender), "USDP: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is able to modify the Vault
    modifier hasVaultAccess() {
        require(parameters.canModifyVault(msg.sender), "USDP: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is the Vault
    modifier onlyVault() {
        require(msg.sender == parameters.vault(), "USDP: AUTH_FAILED");
        _;
    }
}

contract Parameters is Auth {

    // determines the minimum percentage of COL token part in collateral, 0 decimals
    uint public minColPercent;

    // determines the maximum percentage of COL token part in collateral, 0 decimals
    uint public maxColPercent;

    // map token to stability fee percentage; 3 decimals
    mapping(address => uint) public stabilityFee;

    // map token to minimum collateralization percentage; 0 decimals
    mapping(address => uint) public minCollateralizationPercent;

    // map token to liquidation fee percentage, 0 decimals
    mapping(address => uint) public liquidationFee;

    // map token to USDP mint limit
    mapping(address => uint) public tokenDebtLimit;

    // permissions to modify the Vault
    mapping(address => bool) public canModifyVault;

    // managers
    mapping(address => bool) public isManager;

    // enabled oracle types for position spawn
    mapping(uint => bool) public isOracleTypeEnabled;

    // address of the Vault
    address public vault;

    /**
     * The address for an Ethereum contract is deterministically computed from the address of its creator (sender)
     * and how many transactions the creator has sent (nonce). The sender and nonce are RLP encoded and then
     * hashed with Keccak-256.
     * Therefore, the Vault address can be pre-computed and passed as an argument before deployment.
    **/
    constructor(address _vault) public Auth(address(this)) {
        isManager[msg.sender] = true;
        minColPercent = 1; // 1%
        maxColPercent = 5; // 5%
        vault = _vault;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Grants and revokes manager's status of any address
     * @param who The target address
     * @param permit The permission flag
     **/
    function setManager(address who, bool permit) external onlyManager {
        isManager[who] = permit;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets ability to use token as the main collateral
     * @param token The address of a token
     * @param stabilityFeeValue The percentage of the year stability fee (3 decimals)
     * @param liquidationFeeValue The liquidation fee percentage (0 decimals)
     * @param minCollateralizationPercentValue The minimum percentage of the collateral ratio
     * @param usdpLimit The USDP token issue limit
     **/
    function setCollateral(
        address token,
        uint stabilityFeeValue,
        uint liquidationFeeValue,
        uint minCollateralizationPercentValue,
        uint usdpLimit
    ) external onlyManager {
        setStabilityFee(token, stabilityFeeValue);
        setLiquidationFee(token, liquidationFeeValue);
        setMinCollateralizationPercent(token, minCollateralizationPercentValue);
        setTokenDebtLimit(token, usdpLimit);
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets the minimum percentage of the collateral ratio
     * @param token The address of a token
     * @param newValue The percentage with 3 decimals
     **/
    function setMinCollateralizationPercent(address token, uint newValue) public onlyManager {
        require(newValue >= 100, "USDP: INCORRECT_COLLATERALIZATION_VALUE");
        minCollateralizationPercent[token] = newValue;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets a permission for an address to modify the Vault
     * @param who The target address
     * @param permit The permission flag
     **/
    function setVaultAccess(address who, bool permit) external onlyManager {
        canModifyVault[who] = permit;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets the percentage of the year stability fee for a particular collateral
     * @param token The token address
     * @param newValue The stability fee percentage (3 decimals)
     **/
    function setStabilityFee(address token, uint newValue) public onlyManager {
        stabilityFee[token] = newValue;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets the percentage of the liquidation fee for a particular collateral
     * @param token The token address
     * @param newValue The liquidation fee percentage (0 decimals)
     **/
    function setLiquidationFee(address token, uint newValue) public onlyManager {
        liquidationFee[token] = newValue;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets the percentage range of the COL token part in collateral
     * @param min The min percentage (0 decimals)
     * @param max The max percentage (0 decimals)
     **/
    function setColPartRange(uint min, uint max) public onlyManager {
        require(max <= 100 && min <= max, "USDP: WRONG_RANGE");
        minColPercent = min;
        maxColPercent = max;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Enables/disables oracle types
     * @param _type The type of the oracle
     * @param enabled The control flag
     **/
    function setOracleType(uint _type, bool enabled) public onlyManager {
        isOracleTypeEnabled[_type] = enabled;
    }

    /**
     * notice Only manager is able to call this function
     * @dev Sets USDP limit for a specific collateral
     * @param token The token address
     * @param limit The limit number
     **/
    function setTokenDebtLimit(address token, uint limit) public onlyManager {
        tokenDebtLimit[token] = limit;
    }
}
