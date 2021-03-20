const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const { nextBlockNumber } = require('./helpers/time');
const utils = require('./helpers/utils');

contract('LiquidationAuction', function([
	positionOwner,
	liquidator,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'curveLP');
		this.deployer = positionOwner;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	it('Should liquidate triggered position', async function () {

		await this.curvePool.setPool(ether('1.2'), [this.curveLockedAsset.address])

		const collateralAmount = ether('1000');
		const usdpAmount = ether('700');

		await this.utils.join(this.wrappedAsset, collateralAmount, usdpAmount);

		// top up balance of an account performing a liquidation
		await this.wrappedAsset.transfer(liquidator, collateralAmount.mul(new BN('2')));

		const initialLiquidatorUsdpBalance = usdpAmount.mul(new BN('2'));
		await this.utils.join(this.wrappedAsset, collateralAmount.mul(new BN('2')), initialLiquidatorUsdpBalance, { from: liquidator });

		await this.curvePool.setPool(ether('1'), [this.curveLockedAsset.address])

		const collateralOwnerBalanceBefore = await this.wrappedAsset.balanceOf(positionOwner);

		const liquidationTriggerBlock = await nextBlockNumber();
		await this.utils.triggerLiquidation(this.wrappedAsset, positionOwner, liquidator);

		const startingCollateralPrice = await this.vault.liquidationPrice(this.wrappedAsset.address, positionOwner);

		const liquidationFeePercent = await this.vault.liquidationFee(this.wrappedAsset.address, positionOwner);
		const penalty = usdpAmount.mul(liquidationFeePercent).div(new BN(100));

		// approve USDP
		await this.usdp.approve(this.vault.address, penalty, { from: liquidator });

		const buyoutBlock = await nextBlockNumber();

		const { logs } = await this.utils.buyout(this.wrappedAsset, positionOwner, liquidator);

		const devaluationPeriod = await this.vaultManagerParameters.devaluationPeriod(this.wrappedAsset.address);
		const blocksPast = buyoutBlock.sub(liquidationTriggerBlock);
		const debtWithPenalty = usdpAmount.add(penalty);

		let valuationPeriod = new BN('0');
		let collateralPrice = new BN('0');
		let collateralToOwner = new BN('0');
		let repayment = new BN('0');
		let collateralToBuyer;

		if (devaluationPeriod.gt(blocksPast)) {
			valuationPeriod = devaluationPeriod.sub(blocksPast);
			collateralPrice = startingCollateralPrice.mul(valuationPeriod).div(devaluationPeriod);
			if (collateralPrice.gt(debtWithPenalty)) {
				collateralToBuyer = collateralAmount.mul(debtWithPenalty).div(collateralPrice);
				collateralToOwner = collateralAmount.sub(collateralToBuyer);
				repayment = debtWithPenalty;
			} else {
				collateralToBuyer = collateralAmount;
				repayment = collateralPrice;
			}
		} else {
			collateralToBuyer = collateralAmount;
		}

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
		expect(usdpLiquidatorBalance).to.be.bignumber.equal(initialLiquidatorUsdpBalance.sub(repayment));
		expect(collateralLiquidatorBalance).to.be.bignumber.equal(collateralToBuyer);
		expect(collateralOwnerBalanceAfter.sub(collateralOwnerBalanceBefore)).to.be.bignumber.equal(collateralToOwner);
	})

	it('Should send at least 1 wei of 3CRV to CDP owner', async function () {

		await this.curvePool.setPool(ether('1.2'), [this.curveLockedAsset.address])

		const collateralAmount = ether('1000');
		const usdpAmount = ether('700');

		await this.utils.join(this.wrappedAsset, collateralAmount, usdpAmount);

		// top up balance of an account performing a liquidation
		await this.wrappedAsset.transfer(liquidator, collateralAmount.mul(new BN('2')));

		const initialLiquidatorUsdpBalance = usdpAmount.mul(new BN('2'));
		await this.utils.join(this.wrappedAsset, collateralAmount.mul(new BN('2')), initialLiquidatorUsdpBalance, { from: liquidator });

		await this.curvePool.setPool(ether('0.5'), [this.curveLockedAsset.address])

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
