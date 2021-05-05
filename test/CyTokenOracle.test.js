const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

const Q112 = new BN('2').pow(new BN('112'))

contract('CyTokenOracle', function([
	account1,
 	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'cyWETHsample')
		this.deployer = account1
		this.foundation = foundation;
		await this.utils.deploy()
	});

	it('Should check implementation of cyWETH with data from CyTokenOracle', async function () {
		const oracleImplementation = await this.CyTokenOracle.cytokenImplementation();
		const tokenImplementation = await this.cyWETH.implementation();
		expect(tokenImplementation).to.equal(oracleImplementation);
	});

	it('Should check that underlying of cyWETH equal to WETH address', async function () {
		const underlying = await this.cyWETH.underlying();
		expect(underlying).to.equal(this.weth.address);
	});

  let cyWETHamount = 20000000000;

	it('Should check that cyWETH totalSupply not less then cyWETH amount', async function () {
		const supply = await this.cyWETH.totalSupply();
		expect(!(supply < cyWETHamount)).to.be.true;
	});

	it('Should quote cyWETH', async function () {
		const storedRate = await this.cyWETH.exchangeRateStored();
		const rate = await this.CyTokenOracle.bearingToUnderlying(this.cyWETH.address, cyWETHamount);
		// since 1 WETH token costs 250$
		const expectedUsdValue_q112 = rate[1].mul(Q112).mul(new BN('250'));
		const usd_q112 = await this.CyTokenOracle.assetToUsd(this.cyWETH.address, cyWETHamount);
		expect(usd_q112).to.be.bignumber.equal(expectedUsdValue_q112);
	});
});
