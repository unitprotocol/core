const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

const Q112 = new BN('2').pow(new BN('112'))

contract('WstEthOracle', function([
	account1,
 	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'wstETHsample')
		this.deployer = account1
		this.foundation = foundation;
		await this.utils.deploy()
	});

	it('Should check that stETH totalSupply equal setted stETH qty', async function () {
		let stETHamount = 2000000000000000000000000;
		const stETHsupply = await this.stETH.totalSupply();
		expect((stETHsupply == stETHamount)).to.be.true;
	});

	it('Should check that wstETH totalSupply equal setted wstETH qty', async function () {
		let wstETHamount = 3000000000000000000000000;
		const wstETHsupply = await this.wstETH.totalSupply();
		expect((wstETHsupply == wstETHamount)).to.be.true;
	});

	let wstETHqty = 200;
	let stETHgetted;
	let priceFromFeed;

	it('Should check exchange rate wstETH to stETH', async function () {
		let totalPooledEther = 1000000000000000000000000;
		console.log('When totalPooledEther: ', '1 000 000 000000000000000000');
		let totalShares = 2000000000000000000000000;
		console.log('And totalShares: ', '2 000 000 000000000000000000');
    console.log('for wstETHqty: ',wstETHqty);
		const stETHqty = await this.wstETH.getStETHByWstETH(wstETHqty);
		console.log('you get stETHqty: ', stETHqty.toString(10));
		stETHgetted = stETHqty;
		let stETHqtyComp = (wstETHqty * totalPooledEther) / totalShares;
		// console.log('stETHqtyComp: ', stETHqtyComp);
		expect((stETHqty == stETHqtyComp)).to.be.true;
	});

	it('Should check priceCurvePool', async function () {
		let priceSetted = 900000000000000000;
		console.log('priceSetted: ',priceSetted);
		const priceGetted = await this.stETHCurvePool.get_dy(0, 1, '1000000000000000000');
		console.log('priceGetted: ', priceGetted.toString(10));
		expect((priceSetted == priceGetted)).to.be.true;
	});

	it('Should check priceStableSwapStateOracle', async function () {
		let priceSetted = 880000000000000000;
		console.log('priceSetted: ', priceSetted);
		const priceGetted = await this.stETHStableSwapOracle.stethPrice();
		console.log('priceGetted: ', priceGetted.toString(10));
		expect((priceSetted == priceGetted)).to.be.true;
	});

	function percentageDiff(nv, ov) {
			if (nv > ov) {
				return ( nv - ov ) * 10000 / ov;
			} else {
				return ( ov - nv ) * 10000 / ov;
			}
	}

	it('Should check stETHPriceFeed', async function () {
		let priceSettedToCurvePool = 900000000000000000;
		let priceSettedToOracle = 880000000000000000;
		console.log('priceSettedToCurvePool: ', priceSettedToCurvePool);
		console.log('priceSettedToOracle: ', priceSettedToOracle);
		const priceGetted = await this.stETHPriceFeed.full_price_info();
		priceFromFeed = priceGetted[0];
		console.log('priceGettedFromCurvePool: ', priceGetted[0].toString(10));
		console.log('priceIsSafe: ', priceGetted[1].toString());
		console.log('priceGettedFromOracle: ', priceGetted[2].toString(10));
    let poolPrice = Number(priceGetted[0].toString(10));
		let oraclePrice = Number(priceGetted[2].toString(10));
		console.log('percentageDiff: ', percentageDiff(poolPrice, oraclePrice));
		console.log('isSafeByOurselves: ', poolPrice <= 10**18 && !(percentageDiff(poolPrice, oraclePrice) > 500));
		expect((priceSettedToCurvePool == priceGetted[0])).to.be.true;
	});

	it('Should quote wstETH to USDP', async function () {
		console.log('quoted wstETH amount:', wstETHqty);
		let qtyWETHforWstETH = parseInt((stETHgetted * priceFromFeed) / 10**18);
		console.log('qtyStEthforWstETH:', stETHgetted.toString(10));
		console.log('qtyWETHforStEth:', qtyWETHforWstETH.toString(10));

		// since 1 WETH token costs 250$
		const expectedUsdValue_q112 = (new BN(qtyWETHforWstETH)).mul(Q112).mul(new BN('250'));
		const usd_q112 = await this.WstEthOracle.assetToUsd(this.wstETH.address, wstETHqty);
		expect(usd_q112).to.be.bignumber.equal(expectedUsdValue_q112);
	});

});
