// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../VaultParameters.sol";
import "../interfaces/IAggregator.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleEth.sol";
import "../interfaces/IToken.sol";

/**
 * @title ChainlinkedOracleMainAsset
 * @dev Calculates the USD price of desired tokens using Chainlink Oracles.
 * It supports both direct USD pricing and indirect pricing via ETH.
 */
contract ChainlinkedOracleMainAsset is IOracleUsd, IOracleEth, Auth {
    using SafeMath for uint;

    // Mapping from token addresses to their USD Chainlink Aggregator
    mapping (address => address) public usdAggregators;

    // Mapping from token addresses to their ETH Chainlink Aggregator
    mapping (address => address) public ethAggregators;

    // Constant to convert raw Chainlink responses to 18 decimal places
    uint public constant Q112 = 2 ** 112;

    // Constants to define price feed types
    uint public constant USD_TYPE = 0;
    uint public constant ETH_TYPE = 1;

    // Address of the WETH token
    address public immutable WETH;

    // Event emitted when a new aggregator is set
    event NewAggregator(address indexed asset, address indexed aggregator, uint aggType);

    /**
     * @dev Constructor that initializes the contract with predefined aggregators.
     * @param tokenAddresses1 Array of token addresses for USD aggregators.
     * @param _usdAggregators Array of USD Chainlink Aggregator addresses.
     * @param tokenAddresses2 Array of token addresses for ETH aggregators.
     * @param _ethAggregators Array of ETH Chainlink Aggregator addresses.
     * @param weth Address of the WETH token.
     * @param vaultParameters Address of the system's VaultParameters contract.
     */
    constructor(
        address[] memory tokenAddresses1,
        address[] memory _usdAggregators,
        address[] memory tokenAddresses2,
        address[] memory _ethAggregators,
        address weth,
        address vaultParameters
    )
        Auth(vaultParameters)
    {
        require(tokenAddresses1.length == _usdAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        require(tokenAddresses2.length == _ethAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        require(weth != address(0) && vaultParameters != address(0), "Unit Protocol: ZERO_ADDRESS");

        WETH = weth;

        for (uint i = 0; i < tokenAddresses1.length; i++) {
            usdAggregators[tokenAddresses1[i]] = _usdAggregators[i];
            emit NewAggregator(tokenAddresses1[i], _usdAggregators[i], USD_TYPE);
        }

        for (uint i = 0; i < tokenAddresses2.length; i++) {
            ethAggregators[tokenAddresses2[i]] = _ethAggregators[i];
            emit NewAggregator(tokenAddresses2[i], _ethAggregators[i], ETH_TYPE);
        }
    }

    /**
     * @dev Sets new USD and ETH aggregators for specified tokens.
     * Can only be called by the manager role.
     * @param tokenAddresses1 Array of token addresses for USD aggregators.
     * @param _usdAggregators Array of new USD Chainlink Aggregator addresses.
     * @param tokenAddresses2 Array of token addresses for ETH aggregators.
     * @param _ethAggregators Array of new ETH Chainlink Aggregator addresses.
     */
    function setAggregators(
        address[] calldata tokenAddresses1,
        address[] calldata _usdAggregators,
        address[] calldata tokenAddresses2,
        address[] calldata _ethAggregators
    ) external onlyManager {
        require(tokenAddresses1.length == _usdAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        require(tokenAddresses2.length == _ethAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");

        for (uint i = 0; i < tokenAddresses1.length; i++) {
            usdAggregators[tokenAddresses1[i]] = _usdAggregators[i];
            emit NewAggregator(tokenAddresses1[i], _usdAggregators[i], USD_TYPE);
        }

        for (uint i = 0; i < tokenAddresses2.length; i++) {
            ethAggregators[tokenAddresses2[i]] = _ethAggregators[i];
            emit NewAggregator(tokenAddresses2[i], _ethAggregators[i], ETH_TYPE);
        }
    }

    /**
     * @dev Converts the asset amount to its equivalent USD value.
     * @param asset The address of the token to convert.
     * @param amount The amount of the token to convert.
     * @return The Q112-encoded price of the asset amount in USD.
     */
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) {
            return 0;
        }
        if (usdAggregators[asset] != address(0)) {
            return _assetToUsd(asset, amount);
        }
        return ethToUsd(assetToEth(asset, amount));
    }

    /**
     * @dev Internal function to convert the asset amount to its equivalent USD value using the USD aggregator.
     * @param asset The address of the token to convert.
     * @param amount The amount of the token to convert.
     * @return The Q112-encoded price of the asset amount in USD.
     */
    function _assetToUsd(address asset, uint amount) internal view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[asset]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(IToken(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).mul(Q112).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(Q112).mul(10 ** uint(decimals));
        }
    }

    /**
     * @dev Converts the asset amount to its equivalent ETH value.
     * @param asset The address of the token to convert.
     * @param amount The amount of the token to convert.
     * @return The Q112-encoded price of the asset amount in ETH.
     */
    function assetToEth(address asset, uint amount) public view override returns (uint) {
        if (amount == 0) {
            return 0;
        }
        if (asset == WETH) {
            return amount.mul(Q112);
        }
        IAggregator agg = IAggregator(ethAggregators[asset]);

        if (address(agg) == address (0)) {
            // check for usd aggregator
            require(usdAggregators[asset] != address (0), "Unit Protocol: AGGREGATOR_DOES_NOT_EXIST");
            return usdToEth(_assetToUsd(asset, amount));
        }

        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(IToken(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).mul(Q112).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(Q112).mul(10 ** uint(decimals));
        }
    }

    /**
     * @dev Converts the ETH amount to its equivalent USD value using the Chainlink ETH/USD price feed.
     * @param ethAmount The amount of ETH to convert.
     * @return The price of the given amount of Ether in USD (0 decimals).
     */
    function ethToUsd(uint ethAmount) public override view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[WETH]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 6 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        return ethAmount.mul(uint(answer)).div(10 ** agg.decimals());
    }

    /**
     * @dev Converts the USD amount to its equivalent ETH value using the Chainlink ETH/USD price feed.
     * @param _usdAmount The amount of USD to convert.
     * @return The price of the given amount of USD in ETH (0 decimals).
     */
    function usdToEth(uint _usdAmount) public override view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[WETH]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 6 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        return _usdAmount.mul(10 ** agg.decimals()).div(uint(answer));
    }
}