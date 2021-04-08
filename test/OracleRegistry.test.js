const {
		constants : { ZERO_ADDRESS },
		expectEvent
} = require('openzeppelin-test-helpers');
const chai = require('chai');
const assertArrays = require('chai-arrays');
chai.use(assertArrays);
const { expect } = chai;
const { expectRevert } = require('./helpers/utils')(this, 'bearingAssetSimple');
const BN = web3.utils.BN;

const OracleRegistry = artifacts.require('OracleRegistry');
const VaultParameters = artifacts.require('VaultParameters');

contract('CollateralRegistry', function([
	deployer,
	weth,
	oracle1,
	oracle2,
	oracle3,
	asset1,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.vaultParameters = await VaultParameters.new(deployer, deployer);
		this.oracleRegistry = await OracleRegistry.new(this.vaultParameters.address, weth)
	});

	describe('Optimistic cases', function() {

		it('Should set oracle', async function () {

			const oracleType = new BN('1')
			const receipt = await this.oracleRegistry.setOracle(oracleType, oracle1);

			expectEvent(receipt, 'OracleType', { oracleType: oracleType, oracle: oracle1 });

			expect(await this.oracleRegistry.oracleByType(1)).to.equal(oracle1);
			expect(await this.oracleRegistry.maxOracleType()).to.be.bignumber.equal(oracleType);

			const oracles = await this.oracleRegistry.getOracles();

			expect(oracles).to.be.ofSize(1);
			expect(oracles[0].oracleType).to.be.bignumber.equal(oracleType);
			expect(oracles[0].oracleAddress).to.be.equal(oracle1);
		})

		it('Should set oracle for asset', async function () {

			const oracleType = new BN('1')

			await this.oracleRegistry.setOracle(oracleType, oracle1);

			const receipt = await this.oracleRegistry.setOracleTypeForAsset(asset1, oracleType);

			expectEvent(receipt, 'AssetOracle', { asset: asset1 , oracleType: oracleType });

			expect(await this.oracleRegistry.oracleByAsset(asset1)).to.equal(oracle1);
		})

		it('Should unset oracle', async function () {

			const oracleType = new BN('1')
			await this.oracleRegistry.setOracle(oracleType, oracle1);

			const receipt = await this.oracleRegistry.unsetOracle(oracleType);

			expectEvent(receipt, 'OracleType', { oracleType: oracleType, oracle: ZERO_ADDRESS });

			expect(await this.oracleRegistry.oracleByType(oracleType)).to.equal(ZERO_ADDRESS);

			const oracles = await this.oracleRegistry.getOracles();

			expect(oracles).to.be.ofSize(0);
		})

		it('Should unset oracle for asset', async function () {

			const oracleType = new BN('1')

			await this.oracleRegistry.setOracle(oracleType, oracle1);

			await this.oracleRegistry.setOracleTypeForAsset(asset1, oracleType);

			const receipt = await this.oracleRegistry.unsetOracleForAsset(asset1);

			expectEvent(receipt, 'AssetOracle', { asset: asset1 , oracleType: new BN('0') });

			expect(await this.oracleRegistry.oracleByAsset(asset1)).to.equal(ZERO_ADDRESS);
		})

		it('Should set and unset keydonix oracle types', async function () {

			await this.oracleRegistry.setOracle(1, oracle1);
			await this.oracleRegistry.setOracle(2, oracle2);
			await this.oracleRegistry.setOracle(3, oracle3);

			const oracleTypes = [new BN('1'), new BN('2'),new BN('3')]

			let receipt = await this.oracleRegistry.setKeydonixOracleTypes(oracleTypes);

			expectEvent(receipt, 'KeydonixOracleTypes');

			let keydonixOracleTypes = await this.oracleRegistry.getKeydonixOracleTypes();

			expect(keydonixOracleTypes).to.be.ofSize(3);
			keydonixOracleTypes.forEach((_, i) => {
				expect(keydonixOracleTypes[i]).to.be.bignumber.equal(oracleTypes[i]);
			})

			receipt = await this.oracleRegistry.setKeydonixOracleTypes([]);

			expectEvent(receipt, 'KeydonixOracleTypes');

			keydonixOracleTypes = await this.oracleRegistry.getKeydonixOracleTypes();
			expect(keydonixOracleTypes).to.be.ofSize(0);
		})
	});


	describe('Pessimistic cases', function() {
		const describeUnauthorized = function(contract, method, args) {
			describe(`Contract: ${contract}, method: ${method}`, function() {
				it('Should throw on non-authorized access', async function() {
					await expectRevert(this[contract][method](...args, { from: asset1 }), 'Unit Protocol: AUTH_FAILED')
				});
			})
		}

		describeUnauthorized('oracleRegistry', 'setKeydonixOracleTypes', [[new BN('1')]])
		describeUnauthorized('oracleRegistry', 'setOracle', [new BN('1'), oracle1])
		describeUnauthorized('oracleRegistry', 'unsetOracle', [new BN('1')])
		describeUnauthorized('oracleRegistry', 'setOracleTypeForAsset', [asset1, new BN('1')])
		describeUnauthorized('oracleRegistry', 'setOracleTypeForAssets', [[asset1], new BN('1')])
		describeUnauthorized('oracleRegistry', 'unsetOracleForAsset', [asset1])
		describeUnauthorized('oracleRegistry', 'unsetOracleForAssets', [[asset1]])


		it('Should fail to set non-existent oracle for asset', async function() {
			const tx = this.oracleRegistry.setOracleTypeForAsset(asset1, 1);
			await expectRevert(tx, 'Unit Protocol: ZERO_ADDRESS');
		});

		it('Should fail to set invalid oracle type', async function() {
			const tx = this.oracleRegistry.setOracle(0, oracle1);
			await expectRevert(tx, 'Unit Protocol: INVALID_TYPE');
		});
	});
});
