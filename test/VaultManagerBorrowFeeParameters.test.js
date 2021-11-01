const {
		constants : { ZERO_ADDRESS },
		ether
} = require('openzeppelin-test-helpers');
const utils  = require('./helpers/utils');
const BN = web3.utils.BN;
const { expect } = require('chai');

const VaultParameters = artifacts.require('VaultParameters');
const VaultManagerBorrowFeeParameters = artifacts.require('VaultManagerBorrowFeeParameters');
const AssetParametersViewer = artifacts.require('AssetParametersViewer');

const INITIAL_BASE_BORROW_FEE = new BN(1234); // 1.234 %
const INITIAL_FEE_RECEIVER = '0x0000000000000000000000000000000000001234';
const FOUNDATION = '0x0000000000000000000000000123400000001234';
const ASSET1 = '0x0000000000000000000000000123400000001231';
const ASSET2 = '0x0000000000000000000000000123400000001232';

contract('Parameters', function([
	deployer,
	vault,
	thirdAccount,
	fourthAccount,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'keydonixMainAsset');
		this.vaultParameters = await VaultParameters.new(vault, FOUNDATION, {from: deployer});
		this.vaultManagerBorrowFeeParameters = await VaultManagerBorrowFeeParameters.new(this.vaultParameters.address, INITIAL_BASE_BORROW_FEE, INITIAL_FEE_RECEIVER, {from: deployer});
	});

	describe('Optimistic cases', function() {
		it('success read write cases', async function () {
			// initial values
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(INITIAL_BASE_BORROW_FEE);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(INITIAL_BASE_BORROW_FEE);
			expect(await this.vaultManagerBorrowFeeParameters.feeReceiver()).to.be.equal(INITIAL_FEE_RECEIVER);

			const baseBorrowFee = new BN(1);
			const baseBorrowFee2 = new BN(2);
			const assetBorrowFee = new BN(20000);
			const assetBorrowFee2 = new BN(30000);
			const zero = new BN(0);
			const max_fee = new BN(99999);

			// base borrow fee changed
			await this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(baseBorrowFee, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(baseBorrowFee);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(baseBorrowFee);

			// fee receiver changed
			await this.vaultManagerBorrowFeeParameters.setFeeReceiver(thirdAccount, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.feeReceiver()).to.be.equal(thirdAccount);

			// set custom borrow fee for asset 1
			await this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, true, assetBorrowFee, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(assetBorrowFee);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(baseBorrowFee);

			// base fee changed
			await this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(baseBorrowFee2, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(assetBorrowFee);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(baseBorrowFee2);

			// disabled asset 1 custom borrow fee
			await this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, false, assetBorrowFee, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(baseBorrowFee2);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(baseBorrowFee2);

			// changed asset 1 custom borrow fee, but not enabled
			await this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, false, assetBorrowFee2, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(baseBorrowFee2);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(baseBorrowFee2);

			// min value for base borrow fee
			await this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(zero, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(zero);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(zero);

			// max value for base borrow fee
			await this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(max_fee, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(max_fee);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(max_fee);

			// min value for asset1 borrow fee
			await this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, true, zero, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(zero);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(max_fee);

			// max value for asset1 borrow fee
			await this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, true, max_fee, {from: deployer});
			await this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(zero, {from: deployer});
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET1)).to.be.bignumber.equal(max_fee);
			expect(await this.vaultManagerBorrowFeeParameters.getBorrowFee(ASSET2)).to.be.bignumber.equal(zero);
		})
	})

	describe('Pessimistic cases', function() {
		it('only manager can change fee receiver', async function () {
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setFeeReceiver(thirdAccount, {from: thirdAccount}), 'Unit Protocol: AUTH_FAILED')
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setFeeReceiver(thirdAccount, {from: vault}), 'Unit Protocol: AUTH_FAILED')
		})

		it('only manager can change base borrow fee receiver', async function () {
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(new BN(1), {from: thirdAccount}), 'Unit Protocol: AUTH_FAILED')
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(new BN(1), {from: vault}), 'Unit Protocol: AUTH_FAILED')
		})

		it('only manager can change asser borrow fee receiver', async function () {
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET1, true, new BN(1), {from: thirdAccount}), 'Unit Protocol: AUTH_FAILED')
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setAssetBorrowFee(ASSET2, false, new BN(1), {from: vault}), 'Unit Protocol: AUTH_FAILED')
		})

		it('invalid fee receiver', async function () {
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setFeeReceiver(ZERO_ADDRESS, {from: deployer}), 'Unit Protocol: ZERO_ADDRESS')
		})

		it('invalid fee receiver on deploy', async function () {
			await this.utils.expectRevert(
				VaultManagerBorrowFeeParameters.new(this.vaultParameters.address, INITIAL_BASE_BORROW_FEE, ZERO_ADDRESS, {from: deployer}),
				'Unit Protocol: ZERO_ADDRESS'
			)
		})

		it('invalid fee', async function () {
			await this.utils.expectRevert(this.vaultManagerBorrowFeeParameters.setBaseBorrowFee(new BN(100000), {from: deployer}), 'Unit Protocol: INCORRECT_FEE_VALUE')
		})

		it('invalid fee on deploy', async function () {
			await this.utils.expectRevert(
				VaultManagerBorrowFeeParameters.new(this.vaultParameters.address, new BN(100000), INITIAL_FEE_RECEIVER, {from: deployer}),
				'Unit Protocol: INCORRECT_FEE_VALUE'
			)
		})
	});
});
