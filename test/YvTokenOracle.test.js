const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

const Q112 = new BN('2').pow(new BN('112'))

contract('YvTokenOracle', function([
	account1,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'yvWETHsample')
		this.deployer = account1
		await this.utils.deploy()
	});

	it('Should check that yvWETH underlying token is equal WETH address', async function () {
		const underlyingAddress = await this.weth.address;
		const yvWethUnderlyingAddress = await this.yvWETH.token();
		expect(yvWethUnderlyingAddress).to.equal(underlyingAddress);
	});

  let yvWETHamount = 1000000;

	it('Should check that yvWETH totalSupply not less then yvWETH amount', async function () {
		const supply = await this.yvWETH.totalSupply();
		expect(!(supply < yvWETHamount)).to.be.true;
	});

	it('Should quote yvWETH', async function () {
		const pricePerShare = await this.yvWETH.pricePerShare();
		console.log('pricePerShare: ',pricePerShare.toString(10));
		const decimals = await this.yvWETH.decimals();
		console.log('decimals: ',decimals.toString(10));
		console.log('yvWETHamount: ', yvWETHamount);
		const rate = await this.YvTokenOracle.bearingToUnderlying(this.yvWETH.address, yvWETHamount);
		console.log('quoted yvWETHamount:', rate[1].toString(10));
		// since 1 WETH token costs 250$
		const expectedUsdValue_q112 = rate[1].mul(Q112).mul(new BN('250'));
		const usd_q112 = await this.YvTokenOracle.assetToUsd(this.yvWETH.address, yvWETHamount);
		expect(usd_q112).to.be.bignumber.equal(expectedUsdValue_q112);
	});

});
