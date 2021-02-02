const {
		constants : { ZERO_ADDRESS },
		ether
} = require('openzeppelin-test-helpers');
const utils  = require('./helpers/utils');
const BN = web3.utils.BN;
const { expect } = require('chai');

const VaultParameters = artifacts.require('VaultParameters');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const AssetParametersViewer = artifacts.require('AssetParametersViewer');

contract('Parameters', function([
	deployer,
	secondAccount,
	thirdAccount,
	fourthAccount,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'keydonixMainAsset');
		this.vaultParameters = await VaultParameters.new(secondAccount, deployer);
		this.vaultManagerParameters = await VaultManagerParameters.new(this.vaultParameters.address);
		await this.vaultParameters.setManager(this.vaultManagerParameters.address, true);
	});

	describe('Optimistic cases', function() {
		it('Should set another account as manager', async function () {
			await this.vaultParameters.setManager(thirdAccount, true);

			const isManager = await this.vaultParameters.isManager(thirdAccount);

			expect(isManager).to.equal(true);
		})

		it('Should set token as collateral with specified parameters', async function () {
			const expectedTokenDebtLimit = ether('1000000');
			await this.vaultManagerParameters.setCollateral(
				thirdAccount,
				0,
				100,
				67,
				68,
				0,
				1000,
				expectedTokenDebtLimit,
				[1], // enabled oracles
				3,
				5,
			);

			const tokenDebtLimit = await this.vaultParameters.tokenDebtLimit(thirdAccount);

			expect(tokenDebtLimit).to.be.bignumber.equal(expectedTokenDebtLimit);
		})

		it('Should set initial collateral ratio', async function () {
			const expectedInitialCollateralRatio = new BN('67');
			await this.vaultManagerParameters.setInitialCollateralRatio(thirdAccount, expectedInitialCollateralRatio);

			const initialCollateralRatio = await this.vaultManagerParameters.initialCollateralRatio(thirdAccount);

			expect(initialCollateralRatio).to.be.bignumber.equal(expectedInitialCollateralRatio);
		})

		it('Should set liquidation ratio', async function () {
			const expectedLiquidationRatio = new BN('68');
			await this.vaultManagerParameters.setLiquidationRatio(thirdAccount, expectedLiquidationRatio);

			const liquidationRatio = await this.vaultManagerParameters.liquidationRatio(thirdAccount);

			expect(liquidationRatio).to.be.bignumber.equal(expectedLiquidationRatio);
		})

		it('Should set vault access', async function () {
			await this.vaultParameters.setVaultAccess(thirdAccount, true);

			const hasVaultAccess = await this.vaultParameters.canModifyVault(thirdAccount);

			expect(hasVaultAccess).to.equal(true);
		})

		it('Should set stability fee', async function () {
			const expectedStabilityFee = new BN('2000');
			await this.vaultParameters.setStabilityFee(thirdAccount, expectedStabilityFee);

			const stabilityFee = await this.vaultParameters.stabilityFee(thirdAccount);

			expect(stabilityFee).to.be.bignumber.equal(expectedStabilityFee);
		})

		it('Should set liquidation fee', async function () {
			const expectedLiquidationFee = new BN('1');
			await this.vaultParameters.setLiquidationFee(thirdAccount, expectedLiquidationFee);

			const liquidationFee = await this.vaultParameters.liquidationFee(thirdAccount);

			expect(liquidationFee).to.be.bignumber.equal(expectedLiquidationFee);
		})

		it('Should set set COL token part percentage range', async function () {
			const expectedMinColPartRange = new BN('2');
			const expectedMaxColPartRange = new BN('10');
			const asset = thirdAccount;

			await this.vaultManagerParameters.setColPartRange(asset, expectedMinColPartRange, expectedMaxColPartRange);

			const minColPercentage = await this.vaultManagerParameters.minColPercent(asset);
			const maxColPercentage = await this.vaultManagerParameters.maxColPercent(asset);

			expect(minColPercentage).to.be.bignumber.equal(expectedMinColPartRange);
			expect(maxColPercentage).to.be.bignumber.equal(expectedMaxColPartRange);
		})

		it('Should set oracle type enabled', async function () {
			const asset = thirdAccount;
			await this.vaultParameters.setOracleType(0, asset, true);

			const isOracleTypeEnabled = await this.vaultParameters.isOracleTypeEnabled(0, asset);

			expect(isOracleTypeEnabled).to.equal(true);
		})

		it('Should set token debt limit', async function () {
			const expectedTokenDebtLimit = new BN('123456');
			await this.vaultParameters.setTokenDebtLimit(thirdAccount, expectedTokenDebtLimit);

			const tokenDebtLimit = await this.vaultParameters.tokenDebtLimit(thirdAccount);

			expect(tokenDebtLimit).to.be.bignumber.equal(expectedTokenDebtLimit);
		})

		it('Should view parameters', async function () {
		    const viewer = await AssetParametersViewer.new(this.vaultManagerParameters.address);

			await this.vaultManagerParameters.setCollateral(
				thirdAccount,
				1000,
				10,
				67,
				68,
				5000,
				3600,
				ether('1000000'),
				[1, 5], // enabled oracles
				3,
				5,
			);

			await this.vaultManagerParameters.setCollateral(
				fourthAccount,
				1500,
				0,
				17,
				18,
				0,
				36000,
				ether('10000'),
				[7, 5, 28], // enabled oracles
				0,
				0,
			);

            const [asset1, asset2] = await viewer.getMultiAssetParameters.call([thirdAccount, fourthAccount], 50);

            expect(asset1.asset).to.be.equal(thirdAccount);
            expect(asset1.stabilityFee).to.be.bignumber.equal(new BN('1000'));
            expect(asset1.liquidationFee).to.be.bignumber.equal(new BN('10'));
            expect(asset1.initialCollateralRatio).to.be.bignumber.equal(new BN('67'));
            expect(asset1.liquidationRatio).to.be.bignumber.equal(new BN('68'));
            expect(asset1.liquidationDiscount).to.be.bignumber.equal(new BN('5000'));
            expect(asset1.devaluationPeriod).to.be.bignumber.equal(new BN('3600'));
            expect(asset1.tokenDebtLimit).to.be.bignumber.equal(ether('1000000'));
            expect(asset1.oracles).to.deep.equal(['1', '5']);
            expect(asset1.minColPercent).to.be.bignumber.equal(new BN('3'));
            expect(asset1.maxColPercent).to.be.bignumber.equal(new BN('5'));

            expect(asset2.asset).to.be.equal(fourthAccount);
            expect(asset2.stabilityFee).to.be.bignumber.equal(new BN('1500'));
            expect(asset2.liquidationFee).to.be.bignumber.equal(new BN('0'));
            expect(asset2.initialCollateralRatio).to.be.bignumber.equal(new BN('17'));
            expect(asset2.liquidationRatio).to.be.bignumber.equal(new BN('18'));
            expect(asset2.liquidationDiscount).to.be.bignumber.equal(new BN('0'));
            expect(asset2.devaluationPeriod).to.be.bignumber.equal(new BN('36000'));
            expect(asset2.tokenDebtLimit).to.be.bignumber.equal(ether('10000'));
            expect(asset2.oracles).to.deep.equal(['5', '7', '28']);
            expect(asset2.minColPercent).to.be.bignumber.equal(new BN('0'));
            expect(asset2.maxColPercent).to.be.bignumber.equal(new BN('0'));

			const asset1copy = await viewer.getAssetParameters.call(thirdAccount, 50);

            expect(asset1copy.asset).to.be.equal(thirdAccount);
            expect(asset1copy.stabilityFee).to.be.bignumber.equal(new BN('1000'));
            expect(asset1copy.liquidationFee).to.be.bignumber.equal(new BN('10'));
            expect(asset1copy.initialCollateralRatio).to.be.bignumber.equal(new BN('67'));
            expect(asset1copy.liquidationRatio).to.be.bignumber.equal(new BN('68'));
            expect(asset1copy.liquidationDiscount).to.be.bignumber.equal(new BN('5000'));
            expect(asset1copy.devaluationPeriod).to.be.bignumber.equal(new BN('3600'));
            expect(asset1copy.tokenDebtLimit).to.be.bignumber.equal(ether('1000000'));
            expect(asset1copy.oracles).to.deep.equal(['1', '5']);
            expect(asset1copy.minColPercent).to.be.bignumber.equal(new BN('3'));
            expect(asset1copy.maxColPercent).to.be.bignumber.equal(new BN('5'));

            const nonexistent = await viewer.getAssetParameters.call(deployer, 50);
            expect(nonexistent.asset).to.be.equal(deployer);
            expect(nonexistent.tokenDebtLimit).to.be.bignumber.equal(ether('0'));
		})

		it('Should view parameters without oracles search', async function () {
		    const viewer = await AssetParametersViewer.new(this.vaultManagerParameters.address);

			await this.vaultManagerParameters.setCollateral(
				thirdAccount,
				1000,
				10,
				67,
				68,
				5000,
				3600,
				ether('1000000'),
				[1, 5], // enabled oracles
				3,
				5,
			);

			await this.vaultManagerParameters.setCollateral(
				fourthAccount,
				1500,
				0,
				17,
				18,
				0,
				36000,
				ether('10000'),
				[7, 5, 28], // enabled oracles
				0,
				0,
			);

            const [asset1, asset2] = await viewer.getMultiAssetParameters.call([thirdAccount, fourthAccount], 0);

            expect(asset1.asset).to.be.equal(thirdAccount);
            expect(asset1.stabilityFee).to.be.bignumber.equal(new BN('1000'));
            expect(asset1.oracles).to.deep.equal([]);

            expect(asset2.asset).to.be.equal(fourthAccount);
            expect(asset2.stabilityFee).to.be.bignumber.equal(new BN('1500'));
            expect(asset2.oracles).to.deep.equal([]);
		})
	});


	describe('Pessimistic cases', function() {
		const describeUnauthorized = function(contract, method, args) {
			describe(`Contract: ${contract}, method: ${method}`, function() {
				it('Should throw on non-authorized access', async function() {
					await this.utils.expectRevert(this[contract][method](...args, { from: secondAccount }), 'Unit Protocol: AUTH_FAILED')
				});
			})
		}
		const describeIncorrectValue = function(contract, method, args, errMsg) {
			describe(`Contract: ${contract}, method: ${method}`, function() {
				it('Should throw on incorrect value', async function() {
					await this.utils.expectRevert(this[contract][method](...args), `Unit Protocol: ${errMsg}`)
				});
			})
		}
		describeUnauthorized('vaultManagerParameters', 'setCollateral', [
			thirdAccount,
			0,
			100,
			67,
			68,
			0,
			1000,
			ether('100000'),
			[1], // enabled oracles
			3,
			5
		])
		it('Should throw on unauthorized access to vaultParameters', async function() {
			await this.vaultParameters.setManager(this.vaultManagerParameters.address, false);
			const tx = this.vaultManagerParameters.setCollateral(
				thirdAccount,
				0,
				100,
				67,
				68,
				0,
				1000,
				ether('100000'),
				[1], // enabled oracles
				3,
				5
			);
			await this.utils.expectRevert(tx, 'Unit Protocol: AUTH_FAILED');
		});

		describeUnauthorized('vaultManagerParameters', 'setInitialCollateralRatio', [thirdAccount, 1])
		describeIncorrectValue('vaultManagerParameters', 'setInitialCollateralRatio', [thirdAccount, 0], 'INCORRECT_COLLATERALIZATION_VALUE')
		describeIncorrectValue('vaultManagerParameters', 'setInitialCollateralRatio', [thirdAccount, 101], 'INCORRECT_COLLATERALIZATION_VALUE')

		describeUnauthorized('vaultManagerParameters', 'setLiquidationRatio', [thirdAccount, 1])
		describeIncorrectValue('vaultManagerParameters', 'setLiquidationRatio', [thirdAccount, 0], 'INCORRECT_COLLATERALIZATION_VALUE')

		describeUnauthorized('vaultManagerParameters', 'setLiquidationDiscount', [thirdAccount, 1])
		describeIncorrectValue('vaultManagerParameters', 'setLiquidationDiscount', [thirdAccount, 1e5], 'INCORRECT_DISCOUNT_VALUE')

		describeUnauthorized('vaultManagerParameters', 'setDevaluationPeriod', [thirdAccount, 1])
		describeIncorrectValue('vaultManagerParameters', 'setDevaluationPeriod', [thirdAccount, 0], 'INCORRECT_DEVALUATION_VALUE')

		describeUnauthorized('vaultManagerParameters', 'setColPartRange', [thirdAccount, 1, 3])
		describeIncorrectValue('vaultManagerParameters', 'setColPartRange', [thirdAccount, 101, 8], 'WRONG_RANGE')

		describeUnauthorized('vaultParameters', 'setManager', [thirdAccount, true])

		describeUnauthorized('vaultParameters', 'setFoundation', [thirdAccount])
		describeIncorrectValue('vaultParameters', 'setFoundation', [ZERO_ADDRESS], 'ZERO_ADDRESS')

		describeUnauthorized('vaultParameters', 'setCollateral', [thirdAccount, 0, 0, 0, [1]])

		describeUnauthorized('vaultParameters', 'setVaultAccess', [thirdAccount, true])

		describeUnauthorized('vaultParameters', 'setStabilityFee', [thirdAccount, 100])

		describeUnauthorized('vaultParameters', 'setLiquidationFee', [thirdAccount, 100])
		describeIncorrectValue('vaultParameters', 'setLiquidationFee', [thirdAccount, 101], 'VALUE_OUT_OF_RANGE')

		describeUnauthorized('vaultParameters', 'setOracleType', [2, thirdAccount, true])

		describeUnauthorized('vaultParameters', 'setTokenDebtLimit', [thirdAccount, 20000])
	});
});
