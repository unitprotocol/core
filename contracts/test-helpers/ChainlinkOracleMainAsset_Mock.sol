// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "../helpers/SafeMath.sol";
import "../helpers/AggregatorInterface.sol";
import "../VaultParameters.sol";
import "../oracles/OracleSimple.sol";

interface ERC20 {
    function decimals() external view returns(uint8);
}

/**
 * @title ChainlinkOracleMainAsset_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract ChainlinkOracleMainAsset_Mock is ChainlinkedOracleSimple, Auth {
    using SafeMath for uint;

    mapping (address => address) public usdAggregators;
    mapping (address => address) public ethAggregators;

    constructor(
        address[] memory tokenAddresses1,
        address[] memory _usdAggregators,
        address[] memory tokenAddresses2,
        address[] memory _ethAggregators,
        address weth,
        address vaultParameters
    )
        public
        Auth(vaultParameters)
    {
        require(tokenAddresses1.length == _usdAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        require(tokenAddresses2.length == _ethAggregators.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH2");
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

    // override with mock; only for tests
    function assetToUsd(address asset, uint amount) public override view returns (uint) {
        if (amount == 0) {
            return 0;
        }
        if (usdAggregators[asset] != address(0)) {
            return _assetToUsd(asset, amount);
        }
        return ethToUsd(assetToEth(asset, amount));
    }

    function _assetToUsd(address asset, uint amount) internal view returns (uint) {
        AggregatorInterface agg = AggregatorInterface(usdAggregators[asset]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(ERC20(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(10 ** uint(decimals));
        }
    }

    /**
     * @notice {asset}/ETH pair must be registered at Chainlink
     * @param asset The token address
     * @param amount Amount of tokens
     * @return The price of asset amount in ETH
     **/
    function assetToEth(address asset, uint amount) public view override returns (uint) {
        if (amount == 0) {
            return 0;
        }
        if (asset == WETH) {
            return amount;
        }
        require(ethAggregators[asset] != address (0), "Unit Protocol: AGGREGATOR_DOES_NOT_EXIST");
        AggregatorInterface agg = AggregatorInterface(ethAggregators[asset]);
        (, int256 answer, , uint256 updatedAt, ) = agg.latestRoundData();
        require(updatedAt > block.timestamp - 24 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        require(answer >= 0, "Unit Protocol: NEGATIVE_CHAINLINK_PRICE");
        int decimals = 18 - int(ERC20(asset).decimals()) - int(agg.decimals());
        if (decimals < 0) {
            return amount.mul(uint(answer)).div(10 ** uint(-decimals));
        } else {
            return amount.mul(uint(answer)).mul(10 ** uint(decimals));
        }
    }

    /**
     * @notice ETH/USD price feed from Chainlink, see for more info: https://feeds.chain.link/eth-usd
     * returns The price of given amount of Ether in USD (0 decimals)
     **/
    function ethToUsd(uint ethAmount) public override view returns (uint) {
        AggregatorInterface agg = AggregatorInterface(usdAggregators[WETH]);
        require(agg.latestTimestamp() > block.timestamp - 6 hours, "Unit Protocol: STALE_CHAINLINK_PRICE");
        uint ethUsdPrice = uint(agg.latestAnswer());
        return ethAmount.mul(ethUsdPrice).div(10 ** agg.decimals());
    }
}
