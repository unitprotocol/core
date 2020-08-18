const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

contract('Liquidator', function([
	deployer,
	liquidationSystem,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = deployer;
		this.liquidationSystem = liquidationSystem;
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

			/*
			 * Some collateral/WETH pool params before swap:
			 * Some collateral reserve = 125e+12
			 * WETH reserve = 1e+12
			 * 1 some collateral = 1/125 ETH = 2$ (because 1 ETH = 250$)
			 */
			const swapAmount = new BN(10).pow(new BN(14))
			await this.mainCollateral.approve(this.uniswapRouter.address, swapAmount);

			/*
			 * Some collateral/WETH pool params after swap:
			 * Some collateral reserve = 125e+12 + 100e+10 = 225e+12
			 * WETH reserve = 1e+12 - (100e+10 * 997 * 1e+12) / (125e+12 * 1000 + 100e+10 * 997) = 992087113185
			 * 1 some collateral = ~0.0044 ETH = ~ 1.10$
			 */
			await this.uniswapRouter.swapExactTokensForTokens(
				swapAmount,
				'1',
				[this.mainCollateral.address, this.weth.address],
				deployer,
				'9999999999999999',
			);

			/*
			 * Position params after price change:
			 * collateral value = 60 * 1.10 + 5 = 71$
			 * utilization percent = 70 / 71 = 98.5%
			 */
			const { logs } = await this.utils.liquidate(this.mainCollateral, deployer);
			expectEvent.inLogs(logs, 'Liquidation', {
				token: this.mainCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);
			const usdpDebt = await this.vault.getDebt(this.mainCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
		})
	});
});
