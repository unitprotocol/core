// SPDX-License-Identifier: bsl-1.1

pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/ERC20Like.sol";
import "../interfaces/IcyToken.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";
import "../VaultParameters.sol";

/* 
 * @title CyTokenOracle
 * @dev Wrapper to quote cyToken assets like cyWETH, cyDAI, cyUSDT, cyUSDC.
 * @dev cyToken list: https://docs.cream.finance/iron-bank/iron-bank#yearn-token-cytoken
 */
contract CyTokenOracle is IOracleUsd, Auth {
    using SafeMath for uint;

    uint constant expScale = 1e18;

    // Mapping to track enabled cyToken implementations
    mapping (address => bool) public enabledImplementations;

    // Oracle registry to fetch the current oracle for an asset
    IOracleRegistry public immutable oracleRegistry;

    // Event emitted when a cyToken implementation is enabled or disabled
    event ImplementationChanged(address indexed implementation, bool enabled);

    /**
     * @dev Constructs the CyTokenOracle contract.
     * @param _vaultParameters The address of the system's VaultParameters contract.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     * @param impls An array of addresses of the initial cyToken implementations to enable.
     */
    constructor(address _vaultParameters, address _oracleRegistry, address[] memory impls) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        for (uint i = 0; i < impls.length; i++) {
            require(impls[i] != address(0), "Unit Protocol: ZERO_ADDRESS");
            enabledImplementations[impls[i]] = true;
            emit ImplementationChanged(impls[i], true);
        }
    }

    /**
     * @dev Enables or disables a cyToken implementation.
     * @param impl The address of the cyToken implementation.
     * @param enable True to enable or false to disable the implementation.
     */
    function setImplementation(address impl, bool enable) external onlyManager {
        require(impl != address(0), "Unit Protocol: ZERO_ADDRESS");
        enabledImplementations[impl] = enable;
        emit ImplementationChanged(impl, enable);
    }

    /**
     * @dev Converts the amount of cyToken into the equivalent USD value encoded in Q112 format.
     * @param bearing The address of the cyToken.
     * @param amount The amount of cyToken to convert.
     * @return The equivalent USD value encoded in Q112 format.
     */
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        (address underlying, uint underlyingAmount) = bearingToUnderlying(bearing, amount);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(underlying));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(underlying, underlyingAmount);
    }

    /**
     * @dev Converts the amount of cyToken into the underlying asset and its amount.
     * @param bearing The address of the cyToken.
     * @param amount The amount of cyToken to convert.
     * @return _underlying The address of the underlying asset.
     * @return _amount The amount of the underlying asset.
     */
    function bearingToUnderlying(address bearing, uint amount) public view returns (address _underlying, uint _amount) {
        _underlying = IcyToken(bearing).underlying();
        require(_underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        address _implementation = IcyToken(bearing).implementation();
        require(enabledImplementations[_implementation], "Unit Protocol: UNSUPPORTED_CYTOKEN_IMPLEMENTATION");
        uint _exchangeRateStored = IcyToken(bearing).exchangeRateStored();
        uint _totalSupply = ERC20Like(bearing).totalSupply();
        require(amount <= _totalSupply, "Unit Protocol: AMOUNT_EXCEEDS_SUPPLY");
        return (_underlying, amount.mul(_exchangeRateStored).div(expScale));
    }

}