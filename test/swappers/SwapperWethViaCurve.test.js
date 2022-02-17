const {expect} = require("chai");
const {ethers} = require("hardhat");
const {deployContract, attachContract, getRandomSigner} = require("../../test/helpers/ethersUtils");
const {prepareCoreContracts} = require("../../test/helpers/deploy");

const ether = ethers.utils.parseEther;
const BN = ethers.BigNumber.from
const Q112 = BN('2').pow(BN('112'));

let context = {};
describe("SwapperWethViaCurve", function () {
    // negative tests only
    // there is no point in testing logic on mocks. Also we have integration tests for it
    beforeEach(async function () {
        [context.deployer, context.user1, context.user2] = await ethers.getSigners();

        await prepareCoreContracts(context);

        context.usdp = await deployContract("EmptyToken", 'usdp', 'usdp', 18, ether('100'), context.deployer.address);
        context.usdt = await deployContract("EmptyToken", 'usdt', 'usdt', 18, ether('100'), context.deployer.address);

        context.swapper = await deployContract(
            'SwapperWethViaCurve',
            context.vaultParameters.address, context.weth.address, context.usdp.address, context.usdt.address,
            context.weth.address, 1, 3, // just some contract, we will not test logic or success cases
            context.weth.address, 1, 3
        );
    });

    it("negative cases", async function () {
        await expect(
            context.swapper.predictAssetOut(context.usdp.address, ether('1'))
        ).to.be.revertedWith("UNSUPPORTED_ASSET");

        await expect(
            context.swapper.predictUsdpOut(context.usdp.address, ether('1'))
        ).to.be.revertedWith("UNSUPPORTED_ASSET");

        await expect(
            context.swapper.connect(context.user1).swapUsdpToAsset(context.user1.address, context.usdp.address, ether('1'), ether('1'))
        ).to.be.revertedWith("UNSUPPORTED_ASSET");

        await expect(
            context.swapper.connect(context.user1).swapUsdpToAsset(context.user2.address, context.weth.address, ether('1'), ether('1'))
        ).to.be.revertedWith("AUTH_FAILED");

        await expect(
            context.swapper.connect(context.user1).swapAssetToUsdp(context.user1.address, context.usdp.address, ether('1'), ether('1'))
        ).to.be.revertedWith("UNSUPPORTED_ASSET");

        await expect(
            context.swapper.connect(context.user1).swapAssetToUsdp(context.user2.address, context.weth.address, ether('1'), ether('1'))
        ).to.be.revertedWith("AUTH_FAILED");
    });
});
