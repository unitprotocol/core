const {expect} = require("chai");
const {ethers} = require("hardhat");
const {prepareCoreContracts, CASE_BRIDGED_USDP} = require("../helpers/deploy");
const {deployContract} = require("../helpers/ethersUtils");
const {cdpManagerWrapper} = require("../helpers/cdpManagerWrappers");

const ZERO = '0x0000000000000000000000000000000000000000';
const ASSET1 = '0x0000000000000000000000000000000000000001';
const ASSET2 = '0x0000000000000000000000000000000000000002';

BN = ethers.BigNumber.from
const ether = ethers.utils.parseUnits;

let context;

describe(`oracle BridgedUsdpOracle`, function () {

    beforeEach(async function () {
        context = this;

        [this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();
        await prepareCoreContracts(this, CASE_BRIDGED_USDP);

        this.oracle = await deployContract('BridgedUsdpOracle', context.vaultParameters.address, []);
    });

    it(`managers methods`, async function () {
        await expect(
            this.oracle.connect(this.user1).add(ASSET1)
        ).to.be.revertedWith("AUTH_FAILED");

        await expect(
            this.oracle.add(ZERO)
        ).to.be.revertedWith("ZERO_ADDRESS");

        expect(await this.oracle.bridgedUsdp(ASSET1)).to.be.equal(false);
        await this.oracle.add(ASSET1);
        expect(await this.oracle.bridgedUsdp(ASSET1)).to.be.equal(true);

        await expect(
            this.oracle.add(ASSET1)
        ).to.be.revertedWith("ALREADY_ADDED");

        await expect(
            this.oracle.connect(this.user1).remove(ASSET1)
        ).to.be.revertedWith("AUTH_FAILED");

        await expect(
            this.oracle.remove(ZERO)
        ).to.be.revertedWith("ZERO_ADDRESS");

        await expect(
            this.oracle.remove(ASSET2)
        ).to.be.revertedWith("WAS_NOT_ADDED");

        await this.oracle.remove(ASSET1);
        expect(await this.oracle.bridgedUsdp(ASSET1)).to.be.equal(false);
    })

    it(`usdp in constructor`, async function () {
        const oracle = await deployContract('BridgedUsdpOracle', context.vaultParameters.address, [ASSET1, ASSET2]);

        expect(await oracle.bridgedUsdp(ASSET1)).to.be.equal(true);
        expect(await oracle.bridgedUsdp(ASSET2)).to.be.equal(true);

    })

    it(`price`, async function () {
        await this.oracle.add(ASSET1);

        expect(await this.oracle.assetToUsd(ASSET1, 1)).to.be.equal(BN(2).pow(BN(112)));
        expect(await this.oracle.assetToUsd(ASSET1, ether('1'))).to.be.equal(BN(2).pow(BN(112)).mul(ether('1')));
    })

    it(`simple borrow`, async function () {
        await context.vaultManagerParameters.setInitialCollateralRatio(context.collateral.address, 100)
        await context.vaultManagerParameters.setLiquidationRatio(context.collateral.address, 101)

        await context.collateral.transfer(this.user1.address, ether('10'));

        await context.collateral.connect(this.user1).approve(context.vault.address, ether('10'));

        expect(await context.usdp.balanceOf(this.user1.address)).to.be.equal(0)
        await cdpManagerWrapper.join(context, this.user1, context.collateral, ether('5'), ether('5'));
        expect(await context.usdp.balanceOf(this.user1.address)).to.be.equal(ether('5'))

        expect(await context.cdpManager.isLiquidatablePosition(context.collateral.address, this.user1.address)).to.be.equal(false);

        expect(await context.cdpManager.getCollateralUsdValue_q112(context.collateral.address, this.user1.address))
            .to.be.equal(BN(2).pow(BN(112)).mul(ether('5')))


        await context.collateral.transfer(this.user2.address, ether('10'));
        await context.collateral.connect(this.user2).approve(context.vault.address, ether('10'));
        await expect(
            cdpManagerWrapper.join(context, this.user2, context.collateral, ether('5'), ether('5').add(1))
        ).to.be.revertedWith("UNDERCOLLATERALIZED");
    })

});
