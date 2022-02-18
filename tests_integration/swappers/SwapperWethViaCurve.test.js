const {expect} = require("chai");
const {ethers} = require("hardhat");
const {WETH, USDP, ORACLE_CHAINLINK} = require("../../network_constants");
const {deployContract, attachContract, getRandomSigner, Q112, weiToEther, ether, wait} = require("../../test/helpers/ethersUtils");
const {createDeployment: createSwappersDeployment} = require("../../lib/deployments/swappers");
const {runDeployment} = require("../../test/helpers/deployUtils");

let context = {};
describe("SwapperWethViaCurve", function () {

    beforeEach(async function () {
        [context.deployer, ] = await ethers.getSigners();
        context.user1 = getRandomSigner();

        context.weth = await attachContract('WETHMock', WETH);
        context.usdp = await attachContract('USDP', USDP);
        context.chainlinkOracle = await attachContract('IOracleUsd', ORACLE_CHAINLINK);

        const deployment = await createSwappersDeployment({deployer: context.deployer.address});
        const deployed = await runDeployment(deployment, {deployer: context.deployer.address, verify: false});
        context.swapper = await attachContract('SwapperWethViaCurve', deployed.SwapperWethViaCurve);
    });

    it("tests of swap and unswap", async function () {
        const amountWeth = ether('500');
        const amountUsdp = ether('1000000');

        const wethPrice = (await context.chainlinkOracle.assetToUsd(context.weth.address, amountWeth)).div(Q112);
        const wethPrice1weiQ112 = wethPrice.mul(Q112).div(amountWeth);

        await ethers.provider.send("hardhat_setBalance", [context.user1.address, '0x21E19E0C9BAB2400000' /* 10000Ether */]);
        await context.weth.connect(context.user1).deposit({value: amountWeth.mul(2)});

        // swap amountWeth weth to usdp and check swapped amount
        const predictedUsdp = await context.swapper.predictUsdpOut(context.weth.address, amountWeth);
        await context.weth.connect(context.user1).approve(context.swapper.address, amountWeth);
        await context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.weth.address, amountWeth, predictedUsdp.mul(99).div(100)); // exchange with slippage 1%

        const swappedUsdp = await context.usdp.balanceOf(context.user1.address);
        assert(swappedUsdp.gte( wethPrice.mul(97).div(100) )) // slippage with oracle price < 3%
        assert(swappedUsdp.gte( predictedUsdp.mul(99).div(100) )) // slippage with predicted price < 1%

        console.log(`swapped ${weiToEther(amountWeth)} weth to ${weiToEther(swappedUsdp)} usdp. Predicted: ${weiToEther(predictedUsdp)}. Oracle sum: $${weiToEther(wethPrice)}. Oracle price: $${weiToEther(wethPrice1weiQ112.mul(ether('1')).div(Q112))}.`)

        // swap amountUsdp usdp to weth back and check swapped amount
        const predictedWeth = await context.swapper.predictAssetOut(context.weth.address, amountUsdp);
        const balanceWethBefore = await context.weth.balanceOf(context.user1.address);
        await context.usdp.connect(context.user1).approve(context.swapper.address, amountUsdp);
        await context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.weth.address, amountUsdp, predictedWeth.mul(99).div(100));

        const swappedWeth = (await context.weth.balanceOf(context.user1.address)).sub(balanceWethBefore);
        assert(swappedWeth.gte( amountUsdp.mul(Q112).div(wethPrice1weiQ112).mul(97).div(100) )) // slippage with oracle price < 3%
        assert(swappedWeth.gte(predictedWeth.mul(99).div(100))) // slippage with predicted price < 1%

        console.log(`swapped ${weiToEther(amountUsdp)} usdp to ${weiToEther(swappedWeth)} weth. Predicted: ${weiToEther(predictedWeth)}. Oracle sum: ${weiToEther(amountUsdp.mul(Q112).div(wethPrice1weiQ112))}. Oracle price: ${weiToEther(ether('1').mul(Q112).div(wethPrice1weiQ112))}`)
    });
});
