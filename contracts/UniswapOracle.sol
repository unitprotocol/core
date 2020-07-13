// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./helpers/SafeMath.sol";
import "./helpers/ERC20Like.sol";

interface UniswapFactory {
    function getPair(address, address) external view returns (address);
}

contract UniswapOracle {

    using SafeMath for uint;

    /**
    // mainnet addresses
    address constant public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant public DAIWETH = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address constant public USDCWETH = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    UniswapFactory public constant uniswapFactory = UniswapFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    **/

    // ropsten addresses
    address constant public WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address constant public DAIWETH = 0xb6E977D0a27C313DBFB138aD362ec65B88025b1B;
    address constant public DAI = 0x6FD90341D42E30ffA76aa60A5E2a07f6C6A1a17f;
    address constant public USDC = 0x6567f36f64de9398F63C0E9a36F6A826284DfdaA;
    address constant public USDCWETH = 0x5bB7054FD800566F681EfE793c9466457a80560F;

    UniswapFactory public constant uniswapFactory = UniswapFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    function tokenToUsd(address token, uint amount) external view returns (uint result) {
        address uniswapPair = uniswapFactory.getPair(token, WETH);
        require(uniswapPair != address(0), "UniswapOracle: PAIR_DOES_NOT_EXIST");
        uint tokenReserve = ERC20Like(token).balanceOf(uniswapPair);
        uint wethReserve = ERC20Like(WETH).balanceOf(uniswapPair);
        (uint ethUsdNum, uint ethUsdDenom) = ethUsd();
        result = ethUsdNum.mul(amount).mul(wethReserve).div(tokenReserve).div(ethUsdDenom);
    }

    /**
     * returns avg rate between ETH/DAI & ETH/USDC
     **/
    function ethUsd() public view returns (uint, uint) {
        uint daiReserve = ERC20Like(DAI).balanceOf(DAIWETH);
        uint wethReserveDai = ERC20Like(WETH).balanceOf(DAIWETH);

        // multiply by 10^12 to get the same precision
        uint usdcReserve = ERC20Like(USDC).balanceOf(USDCWETH).mul(10 ** 12);
        uint wethReserveUSDC = ERC20Like(WETH).balanceOf(USDCWETH);

        return (daiReserve.add(usdcReserve), wethReserveDai.add(wethReserveUSDC));
    }
}
