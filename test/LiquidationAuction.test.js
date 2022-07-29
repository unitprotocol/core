const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { blockNumberFromReceipt} = require('./helpers/time');
const utils = require('./helpers/utils');
const {getBlockTs} = require("./helpers/ethersUtils");

contract('LiquidationAuction', function([
	positionOwner,
	liquidator,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'curveLP');
		this.deployer = positionOwner;
		await this.utils.deploy();
	});

	it('Should liquidate triggered position', async function () {

		await this.curvePool.setPool(ether('1.2'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])

		const collateralAmount = ether('1000');
		const usdpAmount = ether('700');

		await this.utils.join(this.wrappedAsset, collateralAmount, usdpAmount);

		// top up balance of an account performing a liquidation
		await this.wrappedAsset.transfer(liquidator, collateralAmount.mul(new BN('2')));

		const initialLiquidatorUsdpBalance = usdpAmount.mul(new BN('2'));
		await this.utils.join(this.wrappedAsset, collateralAmount.mul(new BN('2')), initialLiquidatorUsdpBalance, { from: liquidator });

		await this.curvePool.setPool(ether('1'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])

		const collateralOwnerBalanceBefore = await this.wrappedAsset.balanceOf(positionOwner);

		const reciept = await this.utils.triggerLiquidation(this.wrappedAsset, positionOwner, liquidator);
		const liquidationTriggerBlock = await blockNumberFromReceipt(reciept);
		const liquidationTriggerTs = await getBlockTs(liquidationTriggerBlock.toNumber())

		await new Promise(r => setTimeout(r, 3000)); // for ability to test in real network

		const startingCollateralPrice = await this.vault.liquidationPrice(this.wrappedAsset.address, positionOwner);

		const liquidationFeePercent = await this.vault.liquidationFee(this.wrappedAsset.address, positionOwner);
		const penalty = usdpAmount.mul(liquidationFeePercent).div(new BN(100));

		// approve USDP
		await this.usdp.approve(this.vault.address, penalty, { from: liquidator });

		receipt = await this.utils.buyout(this.wrappedAsset, positionOwner, liquidator);
		const { logs } = receipt;
		const buyoutBlock = await blockNumberFromReceipt(receipt);
		const buyoutTs = await getBlockTs(buyoutBlock.toNumber())

		const devaluationPeriod = await this.vaultManagerParameters.devaluationPeriod(this.wrappedAsset.address);
		const secondsPassed = new BN(buyoutTs - liquidationTriggerTs);
		const debtWithPenalty = usdpAmount.add(penalty);

		let valuationPeriod = new BN('0');
		let collateralPrice = new BN('0');
		let collateralToOwner = new BN('0');
		let repayment = new BN('0');
		let collateralToBuyer;

		expect(devaluationPeriod).is.be.bignumber.gt(secondsPassed);

		valuationPeriod = devaluationPeriod.sub(secondsPassed);
		collateralPrice = startingCollateralPrice.mul(valuationPeriod).div(devaluationPeriod);

		expect(collateralPrice).is.be.bignumber.gt(debtWithPenalty)

		collateralToBuyer = collateralAmount.mul(debtWithPenalty).div(collateralPrice);
		collateralToOwner = collateralAmount.sub(collateralToBuyer);
		repayment = debtWithPenalty;

		expectEvent.inLogs(logs, 'Buyout', {
			asset: this.wrappedAsset.address,
			owner: positionOwner,
			buyer: liquidator,
			amount: collateralToBuyer,
			price: repayment,
			penalty: penalty,
		});

		const mainAmountInPositionAfterLiquidation = await this.vault.collaterals(this.wrappedAsset.address, positionOwner);
		const usdpDebt = await this.vault.getTotalDebt(this.wrappedAsset.address, positionOwner);

		const usdpLiquidatorBalance = await this.usdp.balanceOf(liquidator);
		const collateralLiquidatorBalance = await this.wrappedAsset.balanceOf(liquidator);
		const collateralOwnerBalanceAfter = await this.wrappedAsset.balanceOf(positionOwner);

		expect(mainAmountInPositionAfterLiquidation).to.be.bignumber.equal(new BN('0'));
		expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
		expect(usdpLiquidatorBalance).to.be.bignumber.equal(initialLiquidatorUsdpBalance.sub(this.utils.calcBorrowFee(initialLiquidatorUsdpBalance)).sub(repayment));
		expect(collateralLiquidatorBalance).to.be.bignumber.equal(collateralToBuyer);
		expect(collateralOwnerBalanceAfter.sub(collateralOwnerBalanceBefore)).to.be.bignumber.equal(collateralToOwner);
	})

	it('Should send at least 1 wei of 3CRV to CDP owner', async function () {

		await this.curvePool.setPool(ether('1.2'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])

		const collateralAmount = ether('1000');
		const usdpAmount = ether('700');

		await this.utils.join(this.wrappedAsset, collateralAmount, usdpAmount);

		// top up balance of an account performing a liquidation
		await this.wrappedAsset.transfer(liquidator, collateralAmount.mul(new BN('2')));

		const initialLiquidatorUsdpBalance = usdpAmount.mul(new BN('2'));
		await this.utils.join(this.wrappedAsset, collateralAmount.mul(new BN('2')), initialLiquidatorUsdpBalance, { from: liquidator });

		await this.curvePool.setPool(ether('0.5'), [this.curveLockedAsset1.address, this.curveLockedAsset2.address, this.curveLockedAsset3.address])

		const collateralOwnerBalanceBefore = await this.wrappedAsset.balanceOf(positionOwner);

		await this.utils.triggerLiquidation(this.wrappedAsset, positionOwner, liquidator);

		const liquidationFeePercent = await this.vault.liquidationFee(this.wrappedAsset.address, positionOwner);
		const penalty = usdpAmount.mul(liquidationFeePercent).div(new BN(100));

		// approve USDP
		await this.usdp.approve(this.vault.address, penalty, { from: liquidator });

		await this.utils.buyout(this.wrappedAsset, positionOwner, liquidator);

		const collateralOwnerBalanceAfter = await this.wrappedAsset.balanceOf(positionOwner);

		expect(collateralOwnerBalanceAfter.sub(collateralOwnerBalanceBefore)).to.be.bignumber.equal(new BN(1));
	})

});
