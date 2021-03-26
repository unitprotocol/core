const {
		expectEvent
} = require('openzeppelin-test-helpers');
const chai = require('chai');
const assertArrays = require('chai-arrays');
chai.use(assertArrays);
const { expect } = chai;
const { expectRevert } = require('./helpers/utils')(this, 'bearingAssetSimple');
const BN = web3.utils.BN;

const CollateralRegistry = artifacts.require('CollateralRegistry');
const VaultParameters = artifacts.require('VaultParameters');

contract('CollateralRegistry', function([
	deployer,
	collateralAddress1,
	collateralAddress2,
	collateralAddress3,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.vaultParameters = await VaultParameters.new(deployer, deployer);
		this.collateralRegistry = await CollateralRegistry.new(this.vaultParameters.address, [])
	});

	describe('Optimistic cases', function() {

		it('Should not have collaterals initially', async function () {
			const collaterals = await this.collateralRegistry.collaterals();

			expect(collaterals).to.be.ofSize(0);
		})

		it('Should add collateral', async function () {
			const { logs } = await this.collateralRegistry.addCollateral(collateralAddress1);

			expectEvent.inLogs(logs, 'CollateralAdded', { asset: collateralAddress1 });

			const collaterals = await this.collateralRegistry.collaterals();

			expect(collaterals).to.be.equalTo([collateralAddress1]);
			expect(await this.collateralRegistry.isCollateral(collateralAddress1)).to.equal(true);
			expect(await this.collateralRegistry.isCollateral(collateralAddress2)).to.equal(false);
		})

		it('Should remove the last collateral', async function () {
			await this.collateralRegistry.addCollateral(collateralAddress1);
			await this.collateralRegistry.addCollateral(collateralAddress2);
			await this.collateralRegistry.addCollateral(collateralAddress3);
			const { logs } = await this.collateralRegistry.removeCollateral(collateralAddress3);

			expectEvent.inLogs(logs, 'CollateralRemoved', { asset: collateralAddress3 });

			const collaterals = await this.collateralRegistry.collaterals();

			expect(collaterals).to.be.ofSize(2);
			expect(collaterals).to.be.containingAllOf([collateralAddress2, collateralAddress1]);
			expect(await this.collateralRegistry.collateralId(collateralAddress3)).to.be.bignumber.equal(new BN(0));
			expect(await this.collateralRegistry.isCollateral(collateralAddress3)).to.equal(false);
		})

		it('Should remove the first collateral', async function () {
			await this.collateralRegistry.addCollateral(collateralAddress1);
			await this.collateralRegistry.addCollateral(collateralAddress2);
			await this.collateralRegistry.addCollateral(collateralAddress3);
			const { logs } = await this.collateralRegistry.removeCollateral(collateralAddress1);

			expectEvent.inLogs(logs, 'CollateralRemoved', { asset: collateralAddress1 });

			const collaterals = await this.collateralRegistry.collaterals();

			expect(collaterals).to.be.ofSize(2);
			expect(collaterals).to.be.containingAllOf([collateralAddress2, collateralAddress3]);
			expect(await this.collateralRegistry.collateralId(collateralAddress1)).to.be.bignumber.equal(new BN(0));
			expect(await this.collateralRegistry.isCollateral(collateralAddress1)).to.equal(false);
		})

	});


	describe('Pessimistic cases', function() {
		const describeUnauthorized = function(contract, method, args) {
			describe(`Contract: ${contract}, method: ${method}`, function() {
				it('Should throw on non-authorized access', async function() {
					await expectRevert(this[contract][method](...args, { from: collateralAddress1 }), 'Unit Protocol: AUTH_FAILED')
				});
			})
		}

		describeUnauthorized('collateralRegistry', 'addCollateral', [collateralAddress2])
		describeUnauthorized('collateralRegistry', 'removeCollateral', [collateralAddress2])


		it('Should throw adding existing asset', async function() {
			await this.collateralRegistry.addCollateral(collateralAddress2);
			const tx = this.collateralRegistry.addCollateral(collateralAddress2);
			await expectRevert(tx, 'Unit Protocol: ALREADY_EXIST');
		});


		it('Should throw removing non-existent asset', async function() {
			await this.collateralRegistry.addCollateral(collateralAddress1);
			const tx = this.collateralRegistry.removeCollateral(collateralAddress2);
			await expectRevert(tx, 'Unit Protocol: DOES_NOT_EXIST');
		});
	});
});
