const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

contract('LiquidatorUniswapMainAsset', function([
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
			const mainAmount = ether('60');
			const colAmount = ether('5');
			const usdpAmount = ether('70');

			/*
			 * Spawned position params:
			 * collateral value = 60 * 2 + 5 = 125$
			 * utilization percent = 70 / 125 = 56%
			 */
			await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			// fill liquidator usdp balance
			await this.usdp.transfer(liquidator, usdpAmount);
			// approve usdp from liquidator to Vault
			await this.usdp.approve(this.vault.address, usdpAmount);

			/*
			 * Some collateral/WETH pool params before swap:
			 * Some collateral reserve = 125e12
			 * WETH reserve = 1e12
			 * 1 some collateral = 1/125 ETH = 2$ (because 1 ETH = 250$)
			 */
			const mainSwapAmount = new BN(3).mul(new BN(10).pow(new BN(13)))
			await this.mainCollateral.approve(this.uniswapRouter.address, mainSwapAmount);

			const wethReceive = mainSwapAmount.mul(new BN(997)).mul(new BN(1e12)).div(new BN(125e12).mul(new BN(1000)).add(mainSwapAmount.mul(new BN(997))));
			const wethReserve = new BN(1e12).sub(wethReceive);
			const mainReserve = new BN(125e12).add(mainSwapAmount);
			const mainUsdValueAfterSwap = wethReserve.mul(new BN(250)).mul(mainAmount).div(mainReserve);

			/*
			 * Some collateral/WETH pool params after swap:
			 * Some collateral reserve = 125e12 + 30e12 = 155e12
			 * WETH reserve = 806920147183
			 * 1 some collateral = ~0.00247 ETH = ~1.301$
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
			 * collateral value = 60 * 1.301 + 5 = ~83.089$
			 * utilization percent = 70 / 83.089 = ~84.25%
			 */

			const colOwnerBalanceBefore = await this.col.balanceOf(positionOwner);
			const mainOwnerBalanceBefore = await this.mainCollateral.balanceOf(positionOwner);

			const { logs } = await this.utils.liquidate(this.mainCollateral, positionOwner, liquidator);
			expectEvent.inLogs(logs, 'Liquidation', {
				token: this.mainCollateral.address,
				user: positionOwner,
			});

			const penalty = usdpAmount.mul(new BN(13)).div(new BN(100));
			// calculated as COL in position * (debt + penalty) / collateral USD value
			const expectedLiquidatorColBalance = colAmount.mul(usdpAmount.add(penalty)).div(mainUsdValueAfterSwap.add(colAmount));
			const expectedLiquidatorMainBalance = mainAmount.mul(usdpAmount.add(penalty)).div(mainUsdValueAfterSwap.add(colAmount));
			const expectedOwnerColBalanceDiff = colAmount.sub(expectedLiquidatorColBalance);
			const expectedOwnerMainBalanceDiff = mainAmount.sub(expectedLiquidatorMainBalance);

			const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, positionOwner);
			const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, positionOwner);
			const usdpDebt = await this.vault.getTotalDebt(this.mainCollateral.address, positionOwner);

			const usdpLiquidatorBalance = await this.usdp.balanceOf(liquidator);
			const colLiquidatorBalance = await this.col.balanceOf(liquidator);
			const mainLiquidatorBalance = await this.mainCollateral.balanceOf(liquidator);
			const colOwnerBalanceAfter = await this.col.balanceOf(positionOwner);
			const mainOwnerBalanceAfter = await this.mainCollateral.balanceOf(positionOwner);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
			expect(usdpLiquidatorBalance).to.be.bignumber.equal(new BN('0'));
			expect(colLiquidatorBalance).to.be.bignumber.equal(expectedLiquidatorColBalance);
			expect(mainLiquidatorBalance).to.be.bignumber.equal(expectedLiquidatorMainBalance);
			expect(colOwnerBalanceAfter.sub(colOwnerBalanceBefore)).to.be.bignumber.equal(expectedOwnerColBalanceDiff);
			expect(mainOwnerBalanceAfter.sub(mainOwnerBalanceBefore)).to.be.bignumber.equal(expectedOwnerMainBalanceDiff);
		})
	});
});
