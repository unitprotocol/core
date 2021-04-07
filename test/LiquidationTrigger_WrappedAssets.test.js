const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers')
const BN = web3.utils.BN
const { expect } = require('chai')
const { nextBlockNumber } = require('./helpers/time')
const utils = require('./helpers/utils')

contract('LiquidationTriggerSimple', function([
	positionOwner,
	liquidator,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'curveLP')
		this.deployer = positionOwner
		this.foundation = foundation
		await this.utils.deploy()
	});

	it('Should trigger liquidation of undercollateralized position', async function () {
		await this.curvePool.setPool(ether('1.2'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])
		const mainAmount = ether('1000');
		const usdpAmount = ether('700');

		/*
		 * Spawned position params:
		 * utilization percent = 700 / 1200 = ~58.33%
		 */
		await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

		await this.curvePool.setPool(ether('1'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])

		const mainUsdValueAfterDump = ether('1000')

		/*
		 * Position params after price change:
		 * utilization percent = 700 / 1000 = 70%
		 */

		const expectedLiquidationBlock = await nextBlockNumber();

		const totalCollateralUsdValue = mainUsdValueAfterDump;
		const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.wrappedAsset.address);
		const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));

		const { logs } = await this.utils.triggerLiquidation(this.wrappedAsset, positionOwner, liquidator);
		expectEvent.inLogs(logs, 'LiquidationTriggered', {
			asset: this.wrappedAsset.address,
			owner: positionOwner,
		});

		const liquidationBlock = await this.vault.liquidationBlock(this.wrappedAsset.address, positionOwner);
		const liquidationPrice = await this.vault.liquidationPrice(this.wrappedAsset.address, positionOwner);

		expect(liquidationBlock).to.be.bignumber.equal(expectedLiquidationBlock);
		expect(liquidationPrice).to.be.bignumber.equal(expectedLiquidationPrice);
	})

	it('Should fail to trigger liquidation of collateralized position', async function () {
		const mainAmount = ether('50');
		const usdpAmount = ether('25');

		/*
		 * Spawned position params:
		 * collateral value = 50$
		 * utilization percent = 50%
		 */
		await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

		const tx = this.utils.triggerLiquidation(this.wrappedAsset, positionOwner, liquidator);
		await this.utils.expectRevert(tx, "Unit Protocol: SAFE_POSITION");
	})
});
