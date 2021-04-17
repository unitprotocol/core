// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;
pragma abicoder v2;

import "../helpers/ERC20Like.sol";
import "../helpers/SafeMath.sol";
import "../interfaces/IAggregator.sol";
import "../helpers/IUniswapV2Factory.sol";
import "../interfaces/IKeydonixOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";
import "../interfaces/IKeydonixOracleEth.sol";

/**
 * @title KeydonixOracleMainAsset_Mock
 * @dev Calculates the USD price of desired tokens
 **/
contract KeydonixOracleMainAsset_Mock is IKeydonixOracleEth, IKeydonixOracleUsd {
    using SafeMath for uint;

    uint public constant ETH_USD_DENOMINATOR = 1e8;

    uint public constant Q112 = 2 ** 112;

    IUniswapV2Factory public immutable uniswapFactory;

    IOracleRegistry public oracleRegistry;

    address public immutable WETH;

    constructor(
        IUniswapV2Factory uniFactory,
        IOracleRegistry _oracleRegistry
    )
        public
    {
        require(address(uniFactory) != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(address(_oracleRegistry) != address(0), "Unit Protocol: ZERO_ADDRESS");

        uniswapFactory = uniFactory;
        WETH = _oracleRegistry.WETH();
        oracleRegistry = _oracleRegistry;
    }

    /**
     * @notice USD token's rate is UniswapV2 Token/WETH pool's average time weighted price between proofs' blockNumber and current block number
     * @notice Merkle proof must be in range [MIN_BLOCKS_BACK ... MAX_BLOCKS_BACK] blocks ago
     * @notice {Token}/WETH pair must exists on Uniswap
     * @param asset The token address
     * @param amount Amount of tokens
     * @param proofData Merkle proof data
     * @return Q112-encoded price of tokens in USD
     **/
    function assetToUsd(address asset, uint amount, IKeydonixOracleUsd.ProofDataStruct memory proofData) public override view returns (uint) {
        uint priceInEth = assetToEth(asset, amount, proofData);
        return IOracleEth(oracleRegistry.oracleByAsset(WETH)).ethToUsd(priceInEth);
    }

    // override with mock; only for tests
    function assetToEth(address asset, uint amount, IKeydonixOracleUsd.ProofDataStruct memory proofData) public override view returns (uint) {
        if (amount == 0) { return 0; }

        if (asset == WETH) { return amount.mul(Q112); }

        address uniswapPair = uniswapFactory.getPair(asset, WETH);
        require(uniswapPair != address(0), "Unit Protocol: UNISWAP_PAIR_DOES_NOT_EXIST");

        proofData;

        // WETH reserve of {Token}/WETH pool
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);

        // Asset reserve of {Token}/WETH pool
        uint assetReserve = ERC20Like(asset).balanceOf(uniswapPair);

        return amount.mul(wethReserve).mul(Q112).div(assetReserve);
    }
}
