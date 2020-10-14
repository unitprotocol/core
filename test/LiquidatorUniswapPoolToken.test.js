const { expectEvent } = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

contract('LiquidatorUniswapPoolToken', function([
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
			const colUsdValue = colAmount;

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

			const colOwnerBalanceBefore = await this.col.balanceOf(positionOwner);
			const mainOwnerBalanceBefore = await this.poolToken.balanceOf(positionOwner);

			const { logs } = await this.utils.liquidate_Pool(this.poolToken, positionOwner, liquidator);
			expectEvent.inLogs(logs, 'Liquidation', {
				token: this.poolToken.address,
				user: positionOwner,
			});

			const penalty = usdpAmount.mul(new BN(13)).div(new BN(100));
			// calculated as COL in position * (debt + penalty) / collateral USD value
			const expectedLiquidatorColBalance = colAmount.mul(usdpAmount.add(penalty)).div(mainUsdValueAfterSwap.add(colUsdValue));
			const expectedLiquidatorMainBalance = mainAmount.mul(usdpAmount.add(penalty)).div(mainUsdValueAfterSwap.add(colUsdValue));
			const expectedOwnerColBalanceDiff = colAmount.sub(expectedLiquidatorColBalance);
			const expectedOwnerMainBalanceDiff = mainAmount.sub(expectedLiquidatorMainBalance);

			const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, positionOwner);
			const colAmountInPosition = await this.vault.colToken(this.poolToken.address, positionOwner);
			const usdpDebt = await this.vault.getTotalDebt(this.poolToken.address, positionOwner);

			const usdpLiquidatorBalance = await this.usdp.balanceOf(liquidator);
			const colLiquidatorBalance = await this.col.balanceOf(liquidator);
			const mainLiquidatorBalance = await this.poolToken.balanceOf(liquidator);
			const colOwnerBalanceAfter = await this.col.balanceOf(positionOwner);
			const mainOwnerBalanceAfter = await this.poolToken.balanceOf(positionOwner);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
			expect(usdpLiquidatorBalance).to.be.bignumber.equal(new BN('0'));
			expect(mainLiquidatorBalance).to.be.bignumber.equal(expectedLiquidatorMainBalance);
			expect(colLiquidatorBalance).to.be.bignumber.equal(expectedLiquidatorColBalance);
			expect(colOwnerBalanceAfter.sub(colOwnerBalanceBefore)).to.be.bignumber.equal(expectedOwnerColBalanceDiff);
			expect(mainOwnerBalanceAfter.sub(mainOwnerBalanceBefore)).to.be.bignumber.equal(expectedOwnerMainBalanceDiff);
		})
	});
});
