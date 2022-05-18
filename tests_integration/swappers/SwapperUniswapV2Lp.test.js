const {expect} = require("chai");
const {ethers} = require("hardhat");
const {WETH, USDP, ORACLE_CHAINLINK, ORACLE_POOL_TOKEN} = require("../../network_constants");
const {deployContract, attachContract, getRandomSigner, weiToEther, ether, Q112} = require("../../test/helpers/ethersUtils");
const {createDeployment: createSwappersDeployment} = require("../../lib/deployments/swappers");
const {runDeployment} = require("../../test/helpers/deployUtils");

const LP_TOKENS = [
    ["0x703b120F15Ab77B986a24c6f9262364d02f9432f", 'Shiba WETH/USDT'],
    ["0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852", 'Uni WETH/USDT'],
    ["0x06da0fd433C1A5d7a4faa01111c044910A184553", 'Sushi WETH/USDT'],
];

let context = {};
LP_TOKENS.forEach(params =>
    describe(`SwapperUniswapV2Lp for ${params[1]}`, function () {

        beforeEach(async function () {
            [context.deployer, ] = await ethers.getSigners();
            context.user1 = getRandomSigner();

            context.weth = await attachContract('WETHMock', WETH);
            context.usdp = await attachContract('USDP', USDP);
            context.lp = await attachContract('IUniswapV2PairFull', params[0]);
            context.lpTokenOracle = await attachContract('IOracleUsd', ORACLE_POOL_TOKEN);


            const deployment = await createSwappersDeployment({deployer: context.deployer.address});
            const deployed = await runDeployment(deployment, {deployer: context.deployer.address, verify: false});
            context.swapper = await attachContract('SwapperUniswapV2Lp', deployed.SwapperUniswapV2Lp);
            context.swapperWeth = await attachContract('SwapperWethViaCurve', deployed.SwapperWethViaCurve);
        });

        it("tests of swap and unswap", async function () {
            const amountWeth = ether('500');
            const amountUsdp = ether('1000000');

            await getUsdp(amountWeth, amountUsdp);
            ///////////////////
            const lpPrice1ether = (await context.lpTokenOracle.assetToUsd(context.lp.address, ether('1'))).div(Q112);
            const lpPrice1weiQ112 = lpPrice1ether.mul(Q112).div(ether('1'))

            // swap amountUsdp usdp to lp and check swapped amount
            const predictedLp = await context.swapper.predictAssetOut(context.lp.address, amountUsdp);
            await context.usdp.connect(context.user1).approve(context.swapper.address, amountUsdp);
            await context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.lp.address, amountUsdp, predictedLp.mul(99).div(100));

            const swappedLp = (await context.lp.balanceOf(context.user1.address));
            assert(swappedLp.gte( amountUsdp.div(lpPrice1ether).mul(97).div(100) )) // slippage with oracle price < 3%
            assert(swappedLp.gte(predictedLp.mul(99).div(100))) // slippage with predicted price < 1%

            console.log(`swapped ${weiToEther(amountUsdp)} usdp to ${weiToEther(swappedLp)} lp. Predicted: ${weiToEther(predictedLp)}. Oracle sum: ${weiToEther(amountUsdp.mul(Q112).div(lpPrice1weiQ112))}. Oracle price: ${weiToEther(ether('1').mul(Q112).div(lpPrice1weiQ112))}`)

            // swap swappedLp lp to usdp and check swapped amount
            const predictedUsdp = await context.swapper.predictUsdpOut(context.lp.address, swappedLp);
            await context.lp.connect(context.user1).approve(context.swapper.address, swappedLp);
            const balanceUsdpBefore = await context.usdp.balanceOf(context.user1.address);
            await context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.lp.address, swappedLp, predictedUsdp.mul(99).div(100)); // exchange with slippage 1%

            const swappedUsdp = (await context.usdp.balanceOf(context.user1.address)).sub(balanceUsdpBefore);
            assert(swappedUsdp.gte( lpPrice1ether.mul(swappedLp).div(ether('1')).mul(97).div(100) )) // slippage with oracle price < 3%
            assert(swappedUsdp.gte( predictedUsdp.mul(99).div(100) )) // slippage with predicted price < 1%

            console.log(`swapped ${weiToEther(swappedLp)} lp to ${weiToEther(swappedUsdp)} usdp. Predicted: ${weiToEther(predictedUsdp)}. Oracle sum: $${weiToEther(lpPrice1ether.mul(swappedLp).div(ether('1')))}. Oracle price: $${weiToEther(lpPrice1ether)}.`)


        });
    })
);

async function getUsdp(amountWeth, amountUsdp) {
    // get usdp for future swaps
    await ethers.provider.send("hardhat_setBalance", [context.user1.address, '0x152d02c7e14af6800000' /* 100000Ether */]);
    await context.weth.connect(context.user1).deposit({value: amountWeth.mul(2)});
    await context.weth.connect(context.user1).approve(context.swapperWeth.address, amountWeth);
    await context.swapperWeth.connect(context.user1).swapAssetToUsdp(context.user1.address, context.weth.address, amountWeth, amountUsdp);
}
