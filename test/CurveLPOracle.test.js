const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

const Q112 = new BN('2').pow(new BN('112'))

contract('CurveLPOracle', function([
	account1,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'curveLP')
		this.deployer = account1
		await this.utils.deploy()
	});

	it('Should quote curve lp', async function () {

		const usd_q112 = await this.wrappedToUnderlyingOracle.assetToUsd(this.wrappedAsset.address, 1);

		// since 1 virtual price is 1$
		expect(usd_q112).to.be.bignumber.equal(Q112);

	})
});
