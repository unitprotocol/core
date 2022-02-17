const {expect} = require("chai");
const {ethers} = require("hardhat");
const {WETH, USDP, CHAINLINK_ORACLE} = require("../../network_constants");
const {deployContract, attachContract, getRandomSigner} = require("../../test/helpers/ethersUtils");
const {createDeployment: createSwappersDeployment} = require("../../lib/deployments/swappers");
const {runDeployment} = require("../../test/helpers/deployUtils");

const ether = ethers.utils.parseEther;
const BN = ethers.BigNumber.from
const Q112 = BN('2').pow(BN('112'));

let context = {};
describe("SwapperWethViaCurve", function () {

    beforeEach(async function () {
        [context.deployer, ] = await ethers.getSigners();
        context.user1 = getRandomSigner();

        context.weth = await attachContract('ERC20', WETH);
        context.usdp = await attachContract('USDP', USDP);
        context.chainlinkOracle = await attachContract('IOracleUsd', CHAINLINK_ORACLE);

        const deployment = await createSwappersDeployment({deployer: context.deployer.address});
        const deployed = await runDeployment(deployment, {deployer: context.deployer.address, verify: false});
        context.swapper = await attachContract('SwapperWethViaCurve', deployed.SwapperWethViaCurve);
    });

    it("tests of swap and unswap", async function () {
        const amountWeth = ether('1');
        const amountUsdp = ether('1');

        const wethPrice = (await context.chainlinkOracle.assetToUsd(context.weth.address, amountWeth)).div(Q112);
        const usdpToWethPriceQ112 = Q112.mul(ether('1')).div(wethPrice);

        await ethers.provider.send("hardhat_setBalance", [context.user1.address, '0x3635c9adc5dea00000' /* 1000Ether */]);
        await context.weth.connect(context.user1).deposit({value: ether('100')});

        // swap 1 weth to usdp and check swapped amount
        const predictedUsdp = await context.swapper.predictUsdpOut(context.weth.address, amountWeth);
        await context.weth.connect(context.user1).approve(context.swapper.address, amountWeth);
        await context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.weth.address, amountWeth, predictedUsdp.mul(99).div(100)); // exchange with slippage 1%

        const swappedUsdp = await context.usdp.balanceOf(context.user1.address);
        assert(swappedUsdp.gte( wethPrice.mul(97).div(100) )) // slippage with oracle price < 3%
        assert(swappedUsdp.gte( predictedUsdp.mul(99).div(100) )) // slippage with predicted price < 1%

        console.log(`swapped 1 weth to ${weiInEthFloat(swappedUsdp, 2)} usdp. Predicted: ${weiInEthFloat(predictedUsdp, 2)}. Price: $${weiInEthFloat(wethPrice, 2)}.`)

        // swap 1 usdp to weth back and check swapped amount
        const predictedWeth = await context.swapper.predictAssetOut(context.weth.address, amountUsdp);
        const balanceWethBefore = await context.weth.balanceOf(context.user1.address);
        await context.usdp.connect(context.user1).approve(context.swapper.address, amountUsdp);
        await context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.weth.address, amountUsdp, predictedWeth.mul(99).div(100));

        const swappedWeth = (await context.weth.balanceOf(context.user1.address)).sub(balanceWethBefore);
        assert(swappedWeth.mul(Q112).div(ether('1')).gte( usdpToWethPriceQ112.mul(97).div(100) )) // slippage with oracle price < 3%
        assert(swappedWeth.gte(predictedWeth.mul(99).div(100))) // slippage with predicted price < 1%

        console.log(`swapped 1 usdp to ${weiInEthFloat(swappedWeth, 8)} weth. Predicted: ${weiInEthFloat(predictedWeth, 8)}. Price: ${1/+wethPrice.div(ether('1')).toString()}`)
    });
});

function weiInEthFloat(amount, precision) {
    return Number(amount.div(ether((1/10**precision).toFixed(18))).toBigInt())/10**precision
}