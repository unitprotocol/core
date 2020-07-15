const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

contract('VaultManager', function([
	deployer,
	liquidationSystem,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = deployer;
		this.liquidationSystem = liquidationSystem;
		await this.utils.deploy();
		// const tokenPrice = await this.uniswapOracle.tokenToUsd(this.someCollateral.address, '100');
	});

	describe('Optimistic cases', function() {
		it('Should spawn position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('20');
			const usdpAmount = ether('20');

			const { logs } = await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Spawn', {
				collateral: this.someCollateral.address,
				user: deployer,
				oracleType: '1',
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
		})

		it('Should close position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('20');
			const usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.repayAndWithdraw(this.someCollateral, deployer);
			expectEvent.inLogs(logs, 'Destroy', {
				collateral: this.someCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
		})

		it('Should deposit collaterals to position and mint USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('20');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.join(this.someCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Update', {
				collateral: this.someCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
		})

		it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('20');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount.mul(new BN(2)), colAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
		})
	});
});
