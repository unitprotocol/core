// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./helpers/SafeMath.sol";
import "./Parameters.sol";
import "./Vault.sol";
import "./UniswapOracle.sol";
import "./helpers/ERC20Like.sol";

interface OracleLike {
    function tokenToUsd(address, uint) external view returns(uint);
}

contract Liquidator {
    using SafeMath for uint;

    Parameters parameters;
    Vault vault;
    OracleLike uniswapOracle;
    address colToken;
    address liquidationSystem;

    event Liquidation(address token, address user);

    constructor(address _parameters, address _vault, address _uniswapOracle, address _colToken, address _liquidationSystem) public {
        parameters = Parameters(_parameters);
        vault = Vault(_vault);
        uniswapOracle = OracleLike(_uniswapOracle);
        colToken = _colToken;
        liquidationSystem = _liquidationSystem;
    }

    function _isSafePosition(uint collateralUsd, uint debtUsd, uint minColPercent) internal pure returns (bool) {
        return collateralUsd.mul(100).div(debtUsd) >= minColPercent;
    }

    function isSafePosition(address token, address user) public view returns (bool) {
        uint debt = vault.getDebt(token, user);
        if (debt == 0) return true;

        OracleLike _usingOracle;

        // Initially only Uniswap possible
        if (vault.oracleType(token, user) == 1) {
            _usingOracle = uniswapOracle;
        } else revert();

        uint mainCollateralUsd = _usingOracle.tokenToUsd(token, vault.collaterals(token, user));
        uint colTokenUsd = _usingOracle.tokenToUsd(colToken, vault.colToken(token, user));
        return _isSafePosition(mainCollateralUsd.add(colTokenUsd), debt, parameters.minCollateralizationPercent(token));
    }

    function liquidate(address token, address user) external {
        require(!isSafePosition(token, user), "USDP: SAFE_POSITION");
        vault.liquidate(token, user, liquidationSystem);
    }
}
