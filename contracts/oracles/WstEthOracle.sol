// SPDX-License-Identifier: bsl-1.1

pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/ERC20Like.sol";
import "../interfaces/IWstEthToken.sol";
import "../interfaces/IStEthPriceFeed.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";
import "../VaultParameters.sol";

/**
 * @title WstEthOracle
 * @dev Wrapper to quote wstETH ERC20 token that represents the account's share of the total supply of stETH tokens. https://docs.lido.fi/contracts/wsteth/
 **/

contract WstEthOracle is IOracleUsd, Auth  {
    using SafeMath for uint;

    IOracleRegistry public immutable oracleRegistry;

    uint immutable stEthDecimals;

    address public stEthPriceFeed;

    address public WETH;


    event StEthPriceFeedChanged(address indexed implementation);

    constructor(address _vaultParameters, address _oracleRegistry,  uint _stETHDecimals, address _stETHPriceFeed) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0) && _stETHPriceFeed != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        WETH = IOracleRegistry(_oracleRegistry).WETH();
        require(WETH != address(0), "Unit Protocol: ZERO_ADDRESS");
        stEthDecimals = _stETHDecimals;
        stEthPriceFeed = _stETHPriceFeed;
    }

    function setStEthPriceFeed(address impl) external onlyManager {
      require(impl != address(0), "Unit Protocol: ZERO_ADDRESS");
      stEthPriceFeed = impl;
      emit StEthPriceFeedChanged(impl);
    }

    function getDecimalsStEth() public view returns (uint) {
        return stEthDecimals;
    }

    // returns Q112-encoded value
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        uint _qtyStEthByWstEth = IWstEthToken(bearing).getStETHByWstETH(amount);
        (uint _currentPriceStEth, bool _isSafePrice) = IStEthPriceFeed(stEthPriceFeed).current_price();
        require(_isSafePrice == true, "Unit Protocol: STETH_PRICE_IS_NOT_SAFE");
        uint _decimals = getDecimalsStEth();
        uint underlyingAmount = _qtyStEthByWstEth.mul(_currentPriceStEth).div(10**_decimals);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(WETH));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(WETH, underlyingAmount);
    }

}
