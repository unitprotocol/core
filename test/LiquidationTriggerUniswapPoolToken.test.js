const { expectEvent } = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { nextBlockNumber } = require('./helpers/time');
const utils = require('./helpers/utils');

contract('LiquidationTriggerUniswapPoolToken', function([
	positionOwner,
	liquidator,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = positionOwner;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	describe('Optimistic cases', function() {
		it('Should liquidate undercollateralized position', async function () {
			const mainAmount = new BN('3');
			const colAmount = new BN('5');
			const usdpAmount = new BN('78');

			const lpSupply = await this.poolToken.totalSupply();

			/*
			 * Spawned position params:
			 * collateral value = 44.72 * 2 + 5 = 139.16$
			 * utilization percent = 78 / 139.16 = ~56%
			 */
			await this.utils.spawn_Pool(this.poolToken, mainAmount, colAmount, usdpAmount);

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
			 * collateral value after dump = ~112.29 + 5 = ~117.29$
			 */
			await this.uniswapRouter.swapExactTokensForTokens(
				mainSwapAmount,
				'1',
				[this.mainCollateral.address, this.weth.address],
				positionOwner,
				'9999999999999999',
			);

			/*
			 * utilization percent after swap = 78 / 113.128 = ~68.95%
			 */

			const totalCollateralUsdValue = mainUsdValueAfterSwap.add(colAmount);
			const initialDiscount = await this.vaultManagerParameters.liquidationDiscount(this.poolToken.address);

			const expectedLiquidationPrice = totalCollateralUsdValue.sub(totalCollateralUsdValue.mul(initialDiscount).div(new BN(1e5)));
			const expectedLiquidationBlock = await nextBlockNumber();

			const { logs } = await this.utils.triggerLiquidation_Pool(this.poolToken, positionOwner, liquidator);
			expectEvent.inLogs(logs, 'LiquidationTriggered', {
				token: this.poolToken.address,
				user: positionOwner,
			});

			const liquidationBlock = await this.vault.liquidationBlock(this.poolToken.address, positionOwner);
			const liquidationPrice = await this.vault.liquidationPrice(this.poolToken.address, positionOwner);

			expect(liquidationBlock).to.be.bignumber.equal(expectedLiquidationBlock);
			expect(liquidationPrice).to.be.bignumber.equal(expectedLiquidationPrice);
		})
	});
});
