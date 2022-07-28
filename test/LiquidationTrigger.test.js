const {prepareCoreContracts, CASE_ORACLE_MOCK, CASE_ORACLE_KEYDONIX_MOCK} = require("./helpers/deploy");
const {BN, ether, getBlockTs} = require("./helpers/ethersUtils");
const {cdpManagerWrapper, cdpManager} = require("./helpers/cdpManagerWrappers");
const {expect} = require("chai");

const oracleCases = [
    [CASE_ORACLE_MOCK, 'cdp manager'],
    [CASE_ORACLE_KEYDONIX_MOCK, 'cdp manager keydonix'],
]

let context;
oracleCases.forEach(params => {
	describe(`LiquidationTrigger for ${params[1]}`, function () {

		beforeEach(async function () {
			context = this;
			[this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();
			await prepareCoreContracts(this, params[0])
		});

		it("Should trigger liquidation of undercollateralized position and not for ok position", async function () {
			const assetAmount = ether('60');
			const usdpAmount = ether('7000');

			await this.vaultManagerParameters.setLiquidationDiscount(this.collateral.address, 111);

			await this.collateral.transfer(this.user1.address, assetAmount);
			await this.collateral.connect(this.user1).approve(this.vault.address, assetAmount);

			/*
             * Spawned position params (500 - default price for asset):
             * collateral value = 60 * 500 = $30_000
             * cr = 7000 / 30000 = 23.3%
             */
			await cdpManagerWrapper.join(this, this.user1, this.collateral, assetAmount, usdpAmount);

			await expect(
				cdpManagerWrapper.triggerLiquidation(this, this.collateral, this.user1)
			).to.be.revertedWith("Unit Protocol: SAFE_POSITION")

			/*
             * Position params after price change:
             * collateral value = 60 * 150 = $9000
             * utilization percent = 7000 / 9000 = ~77.8%
             */
			const newPrice = BN(120);
			await this.oracle.setRate(newPrice.mul(2n ** 112n));

			const totalCollateralUsdValue = assetAmount.mul(newPrice);
			const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.collateral.address);
			expect(initialDiscount).not.to.be.equal(0);
			const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));

			const receipt = await cdpManagerWrapper.triggerLiquidation(this, this.collateral, this.user1);
			await expect(receipt).to.emit(cdpManager(this), "LiquidationTriggered").withArgs(
				this.collateral.address,
				this.user1.address
			);

			const expectedLiquidationTs = await getBlockTs(receipt.blockNumber);

			const liquidationTs = await this.vault.liquidationTs(this.collateral.address, this.user1.address);
			const liquidationPrice = await this.vault.liquidationPrice(this.collateral.address, this.user1.address);

			expect(liquidationTs).to.be.equal(expectedLiquidationTs);
			expect(liquidationPrice).to.be.equal(expectedLiquidationPrice);
		})
	})
})