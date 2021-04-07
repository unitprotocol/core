const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { nextBlockNumber } = require('./helpers/time');
const utils = require('./helpers/utils');

contract('LiquidationTriggerKeydonixMainAsset', function([
	positionOwner,
	liquidator,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'keydonixMainAsset');
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

		/*
		 * Main collateral/WETH pool params before swap:
		 * Main collateral reserve = 125e12
		 * WETH reserve = 1e12
		 * 1 test collateral = 1/125 ETH = 2$ (because 1 ETH = 250$)
		 */
		const mainSwapAmount = new BN(3).mul(new BN(10).pow(new BN(13)))
		await this.mainCollateral.approve(this.uniswapRouter.address, mainSwapAmount);

		const wethReceive = mainSwapAmount.mul(new BN(997)).mul(new BN(1e12)).div(new BN(125e12).mul(new BN(1000)).add(mainSwapAmount.mul(new BN(997))));
		const wethReserve = new BN(1e12).sub(wethReceive);
		const mainReserve = new BN(125e12).add(mainSwapAmount);
		const mainUsdValueAfterSwap = wethReserve.mul(new BN(250)).mul(mainAmount).div(mainReserve);

		/*
		 * Test collateral/WETH pool params after swap:
		 * Test collateral reserve = 125e12 + 30e12 = 155e12
		 * WETH reserve = 806920147183
		 * 1 test collateral = ~0.00247 ETH = ~1.301$
		 */
		await this.uniswapRouter.swapExactTokensForTokens(
			mainSwapAmount,
			'1',
			[this.mainCollateral.address, this.weth.address],
			positionOwner,
			'9999999999999999',
		);

		/*
		 * Position params after price change:
		 * collateral value = 60 * 1.301 = ~78.06$
		 * utilization percent = 70 / 78.06 = ~89.67%
		 */

		const expectedLiquidationBlock = await nextBlockNumber();

		const totalCollateralUsdValue = mainUsdValueAfterSwap;
		const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.mainCollateral.address);
		const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));

		const { logs } = await this.utils.triggerLiquidation(this.mainCollateral, positionOwner, liquidator);
		expectEvent.inLogs(logs, 'LiquidationTriggered', {
			asset: this.mainCollateral.address,
			owner: positionOwner,
		});

		const liquidationBlock = await this.vault.liquidationBlock(this.mainCollateral.address, positionOwner);
		const liquidationPrice = await this.vault.liquidationPrice(this.mainCollateral.address, positionOwner);

		expect(liquidationBlock).to.be.bignumber.equal(expectedLiquidationBlock);
		expect(liquidationPrice).to.be.bignumber.equal(expectedLiquidationPrice);
	})
});
