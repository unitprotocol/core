const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

const Q112 = new BN('2').pow(new BN('112'))

contract('BearingAssetsOracle', function([
	account1,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'bearingAssetSimple')
		this.deployer = account1
		await this.utils.deploy()
	});

	it('Should quote bearing asset', async function () {
		const supply = await this.bearingAsset.totalSupply()

		const reserve = supply.mul(new BN('2'))
		await this.mainCollateral.transfer(this.bearingAsset.address, reserve)

		const rate = await this.bearingAssetOracle.bearingToUnderlying(this.bearingAsset.address, 1)

		expect(rate[0]).to.equal(this.mainCollateral.address)
		expect(rate[1]).to.be.bignumber.equal(reserve.div(supply));

		const usd_q112 = await this.bearingAssetOracle.assetToUsd(this.bearingAsset.address, supply);

		// since 1 main collateral token costs 2$
		const expectedUsdValue_q112 = reserve.mul(Q112).mul(new BN('2'))

		expect(usd_q112).to.be.bignumber.equal(expectedUsdValue_q112);

	})
});
