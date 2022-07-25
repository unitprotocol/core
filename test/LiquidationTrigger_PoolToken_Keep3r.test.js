const { expectEvent } = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { blockNumberFromReceipt } = require('./helpers/time');
const utils = require('./helpers/utils');

contract('LiquidationTriggerKeep3rPoolToken', function([
 positionOwner,
 liquidator,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'sushiswapKeep3rPoolToken');
		this.deployer = positionOwner;
		await this.utils.deploy();
	});

	it('Should liquidate undercollateralized position', async function () {
		const mainAmount = new BN('3');
		const usdpAmount = new BN('78');

		const lpSupply = await this.poolToken.totalSupply();

		/*
		 * Spawned position params:
		 * collateral value = 44.72 * 2 = 134.16$
		 * utilization percent = 78 / 134.16 = ~58%
		 */
		await this.utils.join(this.poolToken, mainAmount, usdpAmount);

		// fill liquidator usdp balance
		await this.usdp.transfer(liquidator, usdpAmount);
		// approve usdp from liquidator to Vault
		await this.usdp.approve(this.vault.address, usdpAmount);

		/*
		 * Dump the price of underlying token for ~20%
		 */
		const mainSwapAmount = new BN(3).mul(new BN(10).pow(new BN(13)))
		await this.mainCollateral.approve(this.uniswapRouter.address, mainSwapAmount);

		const wethReceive = mainSwapAmount.mul(new BN(997)).mul(new BN(1e12)).div(new BN(125e12).mul(new BN(1000)).add(mainSwapAmount.mul(new BN(997))));
		const wethReserve = new BN(1e12).sub(wethReceive);
		const mainUsdValueAfterSwap = wethReserve.mul(new BN(250)).mul(new BN(2)).mul(mainAmount).div(lpSupply);

		/*
		 * collateral value after dump = ~112.29$
		 */
		await this.uniswapRouter.swapExactTokensForTokens(
			mainSwapAmount,
			'1',
			[this.mainCollateral.address, this.weth.address],
			positionOwner,
			'9999999999999999',
		);

		/*
		 * utilization percent after swap = 78 / 112.29 = ~69.46%
		 */

		const totalCollateralUsdValue = mainUsdValueAfterSwap;
		const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.poolToken.address);

		const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));

		const receipt = await this.utils.triggerLiquidation(this.poolToken, positionOwner, liquidator);
		const { logs } = receipt;
		const expectedLiquidationBlock = await blockNumberFromReceipt(receipt);
		expectEvent.inLogs(logs, 'LiquidationTriggered', {
			asset: this.poolToken.address,
			owner: positionOwner,
		});

		const liquidationBlock = await this.vault.liquidationBlock(this.poolToken.address, positionOwner);
		const liquidationPrice = await this.vault.liquidationPrice(this.poolToken.address, positionOwner);

		expect(liquidationBlock).to.be.bignumber.equal(expectedLiquidationBlock);
		expect(liquidationPrice).to.be.bignumber.equal(expectedLiquidationPrice);
	})

	it('Should fail to trigger liquidation of collateralized position', async function () {
		const mainAmount = new BN('3');
		const usdpAmount = new BN('78');

		await this.utils.join(this.poolToken, mainAmount, usdpAmount);

		const tx = this.utils.triggerLiquidation(this.poolToken, positionOwner, liquidator);
		await this.utils.expectRevert(tx, "Unit Protocol: SAFE_POSITION");
	})

});
