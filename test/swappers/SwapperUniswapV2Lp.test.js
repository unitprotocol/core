const {expect} = require("chai");
const {ethers} = require("hardhat");
const {deployContract, attachContract, getRandomSigner, ether} = require("../../test/helpers/ethersUtils");
const {prepareCoreContracts} = require("../../test/helpers/deploy");

let context = {};
describe("SwapperUniswapV2Lp", function () {
    // negative tests only
    // there is no point in testing logic on mocks. Also we have integration tests for it
    beforeEach(async function () {
        [context.deployer, context.user1, context.user2] = await ethers.getSigners();

        await prepareCoreContracts(context);

        context.usdp = await deployContract("EmptyToken", 'usdp', 'usdp', 18, ether('100'), context.deployer.address);
        context.usdt = await deployContract("EmptyToken", 'usdt', 'usdt', 18, ether('100'), context.deployer.address);

        context.curvePool1 = await deployContract("CurvePool");
        await context.curvePool1.setPool(0, [context.weth.address, context.usdp.address, context.usdt.address]);
        context.curvePool2 = await deployContract("CurvePool");
        await context.curvePool2.setPool(0, [context.weth.address, context.usdp.address, context.usdt.address]);

        context.wethSwapper = await deployContract(
            'SwapperWethViaCurve',
            context.vaultParameters.address, context.weth.address, context.usdp.address, context.usdt.address,
            context.curvePool1.address, context.curvePool2.address
        );

        context.swapper = await deployContract(
            'SwapperUniswapV2Lp',
            context.vaultParameters.address, context.weth.address, context.usdp.address,
            context.wethSwapper.address
        );
    });

    it("negative cases", async function () {
        await expect(
            context.swapper.predictAssetOut(context.usdp.address, ether('1'))
        ).to.be.revertedWith("Transaction reverted");

        await expect(
            context.swapper.predictUsdpOut(context.usdp.address, ether('1'))
        ).to.be.revertedWith("Transaction reverted");

        await expect(
            context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.usdp.address, ether('1'), ether('1'))
        ).to.be.revertedWith("TRANSFER_FROM_FAILED");

        await context.usdp.tests_mint(context.user1.address, ether('2'));
        await context.usdp.connect(context.user1).approve(context.swapper.address, ether('2'));
        await expect(
            context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.usdp.address, ether('1'), ether('1'))
        ).to.be.revertedWith("Transaction reverted");

        await context.usdp.tests_mint(context.user2.address, ether('2'));
        await context.usdp.connect(context.user2).approve(context.swapper.address, ether('2'));
        await expect(
            context.swapper.connect(context.user1).swapUsdpToAsset(context.user2.address, context.weth.address, ether('1'), ether('1'))
        ).to.be.revertedWith("AUTH_FAILED");

        await expect(
            context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.usdt.address, ether('1'), ether('1'))
        ).to.be.revertedWith("TRANSFER_FROM_FAILED");

        await context.usdt.tests_mint(context.user1.address, ether('2'));
        await context.usdt.connect(context.user1).approve(context.swapper.address, ether('2'));
        await expect(
            context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.usdt.address, ether('1'), ether('1'))
        ).to.be.revertedWith("Transaction reverted");

        await context.weth.tests_mint(context.user2.address, ether('2'));
        await context.weth.connect(context.user2).approve(context.swapper.address, ether('2'));
        await expect(
            context.swapper.connect(context.user1).swapAssetToUsdp(context.user2.address, context.weth.address, ether('1'), ether('1'))
        ).to.be.revertedWith("AUTH_FAILED");
    });
});
