const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { nextBlockNumber } = require('./helpers/time');
const utils = require('./helpers/utils');

contract('LiquidationTriggerChainlinkMainAsset', function([
	positionOwner,
	liquidator,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'chainlinkMainAsset');
		this.deployer = positionOwner;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	it('Should trigger liquidation of undercollateralized position', async function () {
		const mainAmount = ether('60');
		const usdpAmount = ether('70');

		/*
		 * Spawned position params:
		 * collateral value = 60 * 2 = 120$
		 * utilization percent = 70 / 120 = 58.3%
		 */
		await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

		const newPriceOfMainInUsd = 1.301e8
		await this.mainUsd.setPrice(newPriceOfMainInUsd);

		/*
		 * Position params after price change:
		 * collateral value = 60 * 1.301 = ~78.06$
		 * utilization percent = 70 / 78.06 = ~89.67%
		 */

		const expectedLiquidationBlock = await nextBlockNumber();

		const totalCollateralUsdValue = mainAmount.mul(new BN(newPriceOfMainInUsd)).div(new BN(1e8));
		const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.mainCollateral.address);
		const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));

		const { logs } = await this.utils.triggerLiquidation(this.mainCollateral, positionOwner, liquidator);
		expectEvent.inLogs(logs, 'LiquidationTriggered', {
			token: this.mainCollateral.address,
			user: positionOwner,
		});

		const liquidationBlock = await this.vault.liquidationBlock(this.mainCollateral.address, positionOwner);
		const liquidationPrice = await this.vault.liquidationPrice(this.mainCollateral.address, positionOwner);

		expect(liquidationBlock).to.be.bignumber.equal(expectedLiquidationBlock);
		expect(liquidationPrice).to.be.bignumber.equal(expectedLiquidationPrice);
	})
});
