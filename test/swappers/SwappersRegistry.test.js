const {expect} = require("chai");
const {ethers} = require("hardhat");
const {deployContract, attachContract, getRandomSigner, ether} = require("../../test/helpers/ethersUtils");
const {prepareCoreContracts} = require("../../test/helpers/deploy");

let context = {};
describe("SwapperRegistry", function () {
    beforeEach(async function () {
        [context.deployer, context.user1, context.swapper1, context.swapper2] = await ethers.getSigners();

        await prepareCoreContracts(context);

        this.swappersRegistry = await deployContract("SwappersRegistry", context.vaultParameters.address)
    });

    it("simple flow", async function () {
        const swapper1 = context.swapper1.address;
        const swapper2 = context.swapper2.address;

        expect(await this.swappersRegistry.getSwappersLength()).to.be.equal(0);
        await expect(
            this.swappersRegistry.getSwapperId(swapper1)
        ).to.be.revertedWith("SWAPPER_IS_NOT_EXIST");
        expect(await this.swappersRegistry.hasSwapper(swapper1)).to.be.equal(false);
        expect(await this.swappersRegistry.getSwappers()).deep.to.be.equal([]);


        await this.swappersRegistry.add(swapper1);
        expect(await this.swappersRegistry.getSwappersLength()).to.be.equal(1);
        expect(await this.swappersRegistry.getSwapperId(swapper1)).to.be.equal(0);
        expect(await this.swappersRegistry.hasSwapper(swapper1)).to.be.equal(true);
        expect(await this.swappersRegistry.hasSwapper(swapper2)).to.be.equal(false);
        expect(await this.swappersRegistry.getSwappers()).deep.to.be.equal([swapper1]);

        await expect(
            this.swappersRegistry.add(swapper1)
        ).to.be.revertedWith("SWAPPER_ALREADY_EXISTS");

        await this.swappersRegistry.add(swapper2);
        expect(await this.swappersRegistry.getSwappersLength()).to.be.equal(2);
        expect(await this.swappersRegistry.getSwapperId(swapper2)).to.be.equal(1);
        expect(await this.swappersRegistry.hasSwapper(swapper1)).to.be.equal(true);
        expect(await this.swappersRegistry.hasSwapper(swapper2)).to.be.equal(true);
        expect(await this.swappersRegistry.getSwappers()).deep.to.be.equal([swapper1, swapper2]);

        await this.swappersRegistry.remove(swapper1);
        expect(await this.swappersRegistry.getSwappersLength()).to.be.equal(1);
        await expect(
            this.swappersRegistry.getSwapperId(swapper1)
        ).to.be.revertedWith("SWAPPER_IS_NOT_EXIST");
        expect(await this.swappersRegistry.getSwapperId(swapper2)).to.be.equal(0); // moved
        expect(await this.swappersRegistry.hasSwapper(swapper1)).to.be.equal(false);
        expect(await this.swappersRegistry.hasSwapper(swapper2)).to.be.equal(true);
        expect(await this.swappersRegistry.getSwappers()).deep.to.be.equal([swapper2]);

        await expect(
            this.swappersRegistry.remove(swapper1)
        ).to.be.revertedWith("SWAPPER_IS_NOT_EXIST");

        await this.swappersRegistry.remove(swapper2);
        expect(await this.swappersRegistry.getSwappersLength()).to.be.equal(0);
        await expect(
            this.swappersRegistry.getSwapperId(swapper2)
        ).to.be.revertedWith("SWAPPER_IS_NOT_EXIST");
        expect(await this.swappersRegistry.hasSwapper(swapper1)).to.be.equal(false);
        expect(await this.swappersRegistry.hasSwapper(swapper2)).to.be.equal(false);
        expect(await this.swappersRegistry.getSwappers()).deep.to.be.equal([]);

    });

    it("negative cases", async function () {
        await expect(
            this.swappersRegistry.connect(context.user1).add(context.swapper1.address)
        ).to.be.revertedWith("AUTH_FAILED");

        await expect(
            this.swappersRegistry.connect(context.user1).remove(context.swapper1.address)
        ).to.be.revertedWith("AUTH_FAILED");
    });
});
