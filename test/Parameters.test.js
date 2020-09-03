const {
	constants : { ZERO_ADDRESS },
	expectEvent,
	expectRevert,
	time,
	ether
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const { calculateAddressAtNonce, deployContractBytecode } = require('./helpers/deployUtils');
const BN = web3.utils.BN;
const { expect } = require('chai');

const Parameters = artifacts.require('Parameters');

contract('Parameters', function([
	deployer,
	secondAccount,
	thirdAccount,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.parameters = await Parameters.new(secondAccount, deployer);
	});

	describe('Optimistic cases', function() {
		it('Should set another account as manager', async function () {
			await this.parameters.setManager(thirdAccount, true);

			const isManager = await this.parameters.isManager(thirdAccount);

			expect(isManager).to.equal(true);
		})

		it('Should set token as collateral with specified parameters', async function () {
			const expectedTokenDebtLimit = ether('1000000');
			await this.parameters.setCollateral(
				thirdAccount,
				0,
				100,
				67,
				68,
				expectedTokenDebtLimit,
				[1], // enabled oracles
				3,
				5,
			);

			const tokenDebtLimit = await this.parameters.tokenDebtLimit(thirdAccount);

			expect(tokenDebtLimit).to.be.bignumber.equal(expectedTokenDebtLimit);
		})

		it('Should set initial collateral ratio', async function () {
			const expectedInitialCollateralRatio = new BN('67');
			await this.parameters.setInitialCollateralRatio(thirdAccount, expectedInitialCollateralRatio);

			const initialCollateralRatio = await this.parameters.initialCollateralRatio(thirdAccount);

			expect(initialCollateralRatio).to.be.bignumber.equal(expectedInitialCollateralRatio);
		})

		it('Should set liquidation ratio', async function () {
			const expectedLiquidationRatio = new BN('68');
			await this.parameters.setLiquidationRatio(thirdAccount, expectedLiquidationRatio);

			const liquidationRatio = await this.parameters.liquidationRatio(thirdAccount);

			expect(liquidationRatio).to.be.bignumber.equal(expectedLiquidationRatio);
		})

		it('Should set vault access', async function () {
			await this.parameters.setVaultAccess(thirdAccount, true);

			const hasVaultAccess = await this.parameters.canModifyVault(thirdAccount);

			expect(hasVaultAccess).to.equal(true);
		})

		it('Should set stability fee', async function () {
			const expectedStabilityFee = new BN('2000');
			await this.parameters.setStabilityFee(thirdAccount, expectedStabilityFee);

			const stabilityFee = await this.parameters.stabilityFee(thirdAccount);

			expect(stabilityFee).to.be.bignumber.equal(expectedStabilityFee);
		})

		it('Should set liquidation fee', async function () {
			const expectedLiquidationFee = new BN('1');
			await this.parameters.setLiquidationFee(thirdAccount, expectedLiquidationFee);

			const liquidationFee = await this.parameters.liquidationFee(thirdAccount);

			expect(liquidationFee).to.be.bignumber.equal(expectedLiquidationFee);
		})

		it('Should set set COL token part percentage range', async function () {
			const expectedMinColPartRange = new BN('2');
			const expectedMaxColPartRange = new BN('10');
			const asset = thirdAccount;

			await this.parameters.setColPartRange(asset, expectedMinColPartRange, expectedMaxColPartRange);

			const minColPercentage = await this.parameters.minColPercent(asset);
			const maxColPercentage = await this.parameters.maxColPercent(asset);

			expect(minColPercentage).to.be.bignumber.equal(expectedMinColPartRange);
			expect(maxColPercentage).to.be.bignumber.equal(expectedMaxColPartRange);
		})

		it('Should set oracle type enabled', async function () {
			const asset = thirdAccount;
			await this.parameters.setOracleType(0, asset, true);

			const isOracleTypeEnabled = await this.parameters.isOracleTypeEnabled(0, asset);

			expect(isOracleTypeEnabled).to.equal(true);
		})

		it('Should set token debt limit', async function () {
			const expectedTokenDebtLimit = new BN('123456');
			await this.parameters.setTokenDebtLimit(thirdAccount, expectedTokenDebtLimit);

			const tokenDebtLimit = await this.parameters.tokenDebtLimit(thirdAccount);

			expect(tokenDebtLimit).to.be.bignumber.equal(expectedTokenDebtLimit);
		})
	});
});
