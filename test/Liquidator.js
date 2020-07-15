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
			const mainAmount = ether('50');
			const colAmount = ether('50');
			const usdpAmount = ether('100');

			await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const swapAmount = new BN(10).pow(new BN(14))
			await this.someCollateral.approve(this.uniswapRouter.address, swapAmount);
			await this.uniswapRouter.swapExactTokensForTokens(
				swapAmount,
				'1',
				[this.someCollateral.address, this.weth.address],
				deployer,
				'9999999999999999',
			);

			const { logs } = await this.utils.liquidate(this.someCollateral, deployer);
			expectEvent.inLogs(logs, 'Liquidation', {
				token: this.someCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpDebt = await this.vault.getDebt(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN('0'));
			expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
		})
	});
});
