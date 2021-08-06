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

    address public stEthPriceFeed;

    uint immutable stEthDecimals;

    address public immutable wstETH;

    address public immutable addressWETH;

    uint constant public MAX_SAFE_PRICE_DIFF = 500;

    event StEthPriceFeedChanged(address indexed implementation);

    constructor(address _vaultParameters, address _oracleRegistry, address _wstETH, address _stETHPriceFeed) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0) && _wstETH != address(0) && _stETHPriceFeed != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        address _addressWETH = IOracleRegistry(_oracleRegistry).WETH();
        require(_addressWETH != address(0), "Unit Protocol: ZERO_ADDRESS");
        addressWETH = _addressWETH;
        stEthPriceFeed = _stETHPriceFeed;
        wstETH = _wstETH;
        address stEthToken = IWstEthToken(_wstETH).stETH();
        require(stEthToken != address(0), "Unit Protocol: ZERO_ADDRESS");
        stEthDecimals = ERC20Like(stEthToken).decimals();
    }

    function setStEthPriceFeed(address impl) external onlyManager {
      require(impl != address(0), "Unit Protocol: ZERO_ADDRESS");
      stEthPriceFeed = impl;
      emit StEthPriceFeedChanged(impl);
    }

    function getDecimalsStEth() public view returns (uint) {
        return stEthDecimals;
    }

    function _percentage_diff(uint nv, uint ov) private pure returns (uint) {
        if (nv > ov) {
          return ( nv - ov ) * 10000 / ov;
        } else {
          return ( ov - nv ) * 10000 / ov;
        }
    }

    function has_changed_unsafely(uint256 pool_price, uint256 oracle_price) private pure returns (bool) {
        return _percentage_diff(pool_price, oracle_price) > MAX_SAFE_PRICE_DIFF;
    }

    // returns Q112-encoded value
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        require(bearing == wstETH, "Unit Protocol: BEARING_IS_NOT_WSTETH");
        if (amount == 0) return 0;
        uint _qtyStEthByWstEth = IWstEthToken(bearing).getStETHByWstETH(amount);
        (uint _poolPriceStEth, bool _isSafePrice, uint _oraclePriceStEth) = IStEthPriceFeed(stEthPriceFeed).full_price_info();
        _isSafePrice = _poolPriceStEth <= 10**18 && !has_changed_unsafely(_poolPriceStEth, _oraclePriceStEth);
        require(_isSafePrice == true, "Unit Protocol: STETH_PRICE_IS_NOT_SAFE");
        uint _decimals = getDecimalsStEth();
        uint underlyingAmount = _qtyStEthByWstEth.mul(_poolPriceStEth).div(10**_decimals);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(addressWETH));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(addressWETH, underlyingAmount);
    }

}
