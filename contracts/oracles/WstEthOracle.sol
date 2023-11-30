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

    // Oracle Registry contract address
    IOracleRegistry public immutable oracleRegistry;

    // StETH price feed contract address
    address public stEthPriceFeed;

    // StETH token decimals
    uint immutable stEthDecimals;

    // wstETH token contract address
    address public immutable wstETH;

    // Wrapped ETH token contract address
    address public immutable addressWETH;

    // Maximum safe price deviation (in basis points)
    uint constant public MAX_SAFE_PRICE_DIFF = 500;

    // Event emitted when stEthPriceFeed is changed
    event StEthPriceFeedChanged(address indexed implementation);

    /* @notice Creates a WstEthOracle instance.
     * @param _vaultParameters The address of the system's VaultParameters contract.
     * @param _oracleRegistry The address of the OracleRegistry contract.
     * @param _wstETH The address of the wstETH token contract.
     * @param _stETHPriceFeed The address of the StETH price feed contract.
     */
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

    /* @notice Sets the StETH price feed contract address.
     * @param impl The address of the new StETH price feed contract.
     */
    function setStEthPriceFeed(address impl) external onlyManager {
      require(impl != address(0), "Unit Protocol: ZERO_ADDRESS");
      stEthPriceFeed = impl;
      emit StEthPriceFeedChanged(impl);
    }

    /* @notice Returns the number of decimals of the StETH token.
     * @return The number of decimals for StETH.
     */
    function getDecimalsStEth() public view returns (uint) {
        return stEthDecimals;
    }

    /* @notice Calculates the percentage difference between two values.
     * @param nv New value for comparison.
     * @param ov Old value for comparison.
     * @return The percentage difference (in basis points).
     */
    function _percentage_diff(uint nv, uint ov) private pure returns (uint) {
        if (nv > ov) {
          return ( nv - ov ) * 10000 / ov;
        } else {
          return ( ov - nv ) * 10000 / ov;
        }
    }

    /* @notice Determines if the price has changed unsafely.
     * @param pool_price The price from the liquidity pool.
     * @param oracle_price The price from the oracle.
     * @return True if the price difference exceeds the safe threshold.
     */
    function has_changed_unsafely(uint256 pool_price, uint256 oracle_price) private pure returns (bool) {
        return _percentage_diff(pool_price, oracle_price) > MAX_SAFE_PRICE_DIFF;
    }

    /* @notice Converts wstETH to USD.
     * @param bearing The address of the wstETH token contract.
     * @param amount The amount of wstETH to convert.
     * @return The equivalent USD value, Q112-encoded.
     */
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