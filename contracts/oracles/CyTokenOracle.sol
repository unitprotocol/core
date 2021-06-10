// SPDX-License-Identifier: bsl-1.1

pragma solidity 0.7.6;

import "../helpers/SafeMath.sol";
import "../helpers/ERC20Like.sol";
import "../interfaces/IcyToken.sol";
import "../interfaces/IOracleUsd.sol";
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/IOracleEth.sol";
import "../VaultParameters.sol";

/**
 * @title CyTokenOracle
 * @dev Wrapper to quote cyToken assets like cyWETH, cyDAI, cyUSDT, cyUSDC
 * @dev cyToken list:  https://docs.cream.finance/iron-bank/iron-bank#yearn-token-cytoken
 **/

contract CyTokenOracle is IOracleUsd, Auth  {
    using SafeMath for uint;

    uint constant expScale = 1e18;

    mapping (address => bool) public enabledImplementations;

    IOracleRegistry public immutable oracleRegistry;

    event ImplementationChanged(address indexed implementation, bool enabled);

    constructor(address _vaultParameters, address _oracleRegistry, address[] memory impls) Auth(_vaultParameters) {
        require(_vaultParameters != address(0) && _oracleRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        for (uint i = 0; i < impls.length; i++) {
          require(impls[i] != address(0), "Unit Protocol: ZERO_ADDRESS");
          enabledImplementations[impls[i]] = true;
          emit ImplementationChanged(impls[i], true);
        }
    }

    function setImplementation(address impl, bool enable) external onlyManager {
      require(impl != address(0), "Unit Protocol: ZERO_ADDRESS");
      enabledImplementations[impl] = enable;
      emit ImplementationChanged(impl, enable);
    }

    // returns Q112-encoded value
    function assetToUsd(address bearing, uint amount) public override view returns (uint) {
        if (amount == 0) return 0;
        (address underlying, uint underlyingAmount) = bearingToUnderlying(bearing, amount);
        IOracleUsd _oracleForUnderlying = IOracleUsd(oracleRegistry.oracleByAsset(underlying));
        require(address(_oracleForUnderlying) != address(0), "Unit Protocol: ORACLE_NOT_FOUND");
        return _oracleForUnderlying.assetToUsd(underlying, underlyingAmount);
    }

    function bearingToUnderlying(address bearing, uint amount) public view returns (address, uint) {
        address _underlying = IcyToken(bearing).underlying();
        require(_underlying != address(0), "Unit Protocol: UNDEFINED_UNDERLYING");
        address _implementation = IcyToken(bearing).implementation();
        require(enabledImplementations[_implementation], "Unit Protocol: UNSUPPORTED_CYTOKEN_IMPLEMENTATION");
        uint _exchangeRateStored = IcyToken(bearing).exchangeRateStored();
        uint _totalSupply = ERC20Like(bearing).totalSupply();
        require(amount <= _totalSupply, "Unit Protocol: AMOUNT_EXCEEDS_SUPPLY");
        return (_underlying, amount.mul(_exchangeRateStored).div(expScale));
    }

}
