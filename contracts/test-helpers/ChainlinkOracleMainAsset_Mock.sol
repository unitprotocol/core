// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../helpers/SafeMath.sol";
import "../interfaces/IAggregator.sol";
import "../interfaces/IERC20WithOptional.sol";
import "../VaultParameters.sol";
import "../oracles/OracleSimple.sol";

/**
 * @title ChainlinkOracleMainAsset_Mock
 * @dev Mock contract to calculate the USD price of desired tokens using Chainlink oracles.
 */
contract ChainlinkOracleMainAsset_Mock is ChainlinkedOracleSimple, Auth {
    using SafeMath for uint;

    // Mapping of token addresses to their respective USD Chainlink Price Feed aggregators
    mapping (address => address) public usdAggregators;

    // Mapping of token addresses to their respective ETH Chainlink Price Feed aggregators
    mapping (address => address) public ethAggregators;

    // Constant to scale asset price
    uint public constant Q112 = 2 ** 112;

    /**
     * @notice Constructor sets initial aggregators for tokens
     * @param tokenAddresses1 Array of token addresses for which USD aggregators are being set
     * @param _usdAggregators Array of Chainlink USD aggregator addresses corresponding to token addresses
     * @param tokenAddresses2 Array of token addresses for which ETH aggregators are being set
     * @param _ethAggregators Array of Chainlink ETH aggregator addresses corresponding to token addresses
     * @param weth Address of the Wrapped Ether token
     * @param vaultParameters Address of the VaultParameters contract
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
        require(weth != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(vaultParameters != address(0), "Unit Protocol: ZERO_ADDRESS");

        WETH = weth;

        for (uint i = 0; i < tokenAddresses1.length; i++) {
            usdAggregators[tokenAddresses1[i]] = _usdAggregators[i];
        }

        for (uint i = 0; i < tokenAddresses2.length; i++) {
            ethAggregators[tokenAddresses2[i]] = _ethAggregators[i];
        }
    }

    /**
     * @notice Sets or updates the USD and ETH aggregators for the given tokens
     * @param tokenAddresses1 Array of token addresses for which USD aggregators are being set or updated
     * @param _usdAggregators Array of new Chainlink USD aggregator addresses
     * @param tokenAddresses2 Array of token addresses for which ETH aggregators are being set or updated
     * @param _ethAggregators Array of new Chainlink ETH aggregator addresses
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
        }

        for (uint i = 0; i < tokenAddresses2.length; i++) {
            ethAggregators[tokenAddresses2[i]] = _ethAggregators[i];
        }
    }

    /**
     * @notice Converts the amount of the given asset to its equivalent in USD
     * @dev The {asset}/USD or {asset}/ETH pair must be registered at Chainlink
     * @param asset The token address
     * @param amount The amount of tokens to convert
     * @return The equivalent amount of the asset in USD
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
     * @dev Internal function to convert the amount of the given asset to its equivalent in USD
     * @param asset The token address
     * @param amount The amount of tokens to convert
     * @return The equivalent amount of the asset in USD
     */
    function _assetToUsd(address asset, uint amount) internal view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[asset]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(IERC20WithOptional(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).mul(Q112).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(Q112).mul(10 ** uint(decimals));
        }
    }

    /**
     * @notice Converts the amount of the given asset to its equivalent in ETH
     * @dev The {asset}/ETH pair must be registered at Chainlink
     * @param asset The token address
     * @param amount The amount of tokens to convert
     * @return The equivalent amount of the asset in ETH
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
            return _usdToEth(_assetToUsd(asset, amount));
        }

        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(IERC20WithOptional(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).mul(Q112).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(Q112).mul(10 ** uint(decimals));
        }
    }

    /**
     * @notice ETH/USD price feed from Chainlink, see for more info: https://feeds.chain.link/eth-usd
     * @param ethAmount The amount of Ether to convert
     * @return The price of given amount of Ether in USD (0 decimals)
     */
    function ethToUsd(uint ethAmount) public override view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[WETH]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 6 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        return ethAmount.mul(uint(answer)).div(10 ** agg.decimals());
    }

    /**
     * @dev Internal function to convert the given amount of USD to its equivalent in ETH
     * @param usdAmount The amount of USD to convert
     * @return The equivalent amount of USD in ETH
     */
    function _usdToEth(uint usdAmount) internal view returns (uint) {
        IAggregator agg = IAggregator(usdAggregators[WETH]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 6 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        return usdAmount.mul(10 ** agg.decimals()).div(uint(answer));
    }
}