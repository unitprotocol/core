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
		this.utils = utils(this, 'keep3rMainAsset');
		this.deployer = positionOwner;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	it('Should liquidate triggered position', async function () {
		const mainAmount = ether('60');
		const colAmount = ether('5');
		const usdpAmount = ether('70');

		await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

		// top up balance of an account performing a liquidation
		await this.mainCollateral.transfer(liquidator, mainAmount.mul(new BN('2')));
		await this.col.transfer(liquidator, colAmount.mul(new BN('2')));

		const initialLiquidatorUsdpBalance = usdpAmount.mul(new BN('2'));
		await this.utils.spawn(this.mainCollateral, mainAmount.mul(new BN('2')), colAmount.mul(new BN('2')), initialLiquidatorUsdpBalance, { from: liquidator });

		const mainSwapAmount = new BN(3).mul(new BN(10).pow(new BN(13)))
		await this.mainCollateral.approve(this.uniswapRouter.address, mainSwapAmount);

		await this.uniswapRouter.swapExactTokensForTokens(
			mainSwapAmount,
			'1',
			[this.mainCollateral.address, this.weth.address],
			positionOwner,
			'9999999999999999',
		);

		const colOwnerBalanceBefore = await this.col.balanceOf(positionOwner);
		const mainOwnerBalanceBefore = await this.mainCollateral.balanceOf(positionOwner);

		const liquidationTriggerBlock = await nextBlockNumber();
		await this.utils.triggerLiquidation(this.mainCollateral, positionOwner, liquidator);

		const startingCollateralPrice = await this.vault.liquidationPrice(this.mainCollateral.address, positionOwner);

		const liquidationFeePercent = await this.vault.liquidationFee(this.mainCollateral.address, positionOwner);
		const penalty = usdpAmount.mul(liquidationFeePercent).div(new BN(100));

		// approve USDP
		await this.usdp.approve(this.vault.address, penalty, { from: liquidator });

		const buyoutBlock = await nextBlockNumber();

		const { logs } = await this.utils.buyout(this.mainCollateral, positionOwner, liquidator);
		expectEvent.inLogs(logs, 'Liquidated', {
			token: this.mainCollateral.address,
			user: positionOwner,
		});

		const devaluationPeriod = await this.vaultManagerParameters.devaluationPeriod(this.mainCollateral.address);
		const blocksPast = buyoutBlock.sub(liquidationTriggerBlock);
		const debtWithPenalty = usdpAmount.add(penalty);

		let valuationPeriod = new BN('0');
		let collateralPrice = new BN('0');
		let mainToOwner = new BN('0');
		let colToOwner = new BN('0');
		let repayment = new BN('0');
		let mainToLiquidator;
		let colToLiquidator;

		if (devaluationPeriod.gt(blocksPast)) {
			valuationPeriod = devaluationPeriod.sub(blocksPast);
			collateralPrice = startingCollateralPrice.mul(valuationPeriod).div(devaluationPeriod);
			if (collateralPrice.gt(debtWithPenalty)) {
				const ownerShare = collateralPrice.sub(debtWithPenalty);
				mainToLiquidator = mainAmount.mul(debtWithPenalty).div(collateralPrice);
				colToLiquidator = colAmount.mul(debtWithPenalty).div(collateralPrice);
				mainToOwner = mainAmount.mul(ownerShare).div(collateralPrice);
				colToOwner = colAmount.mul(ownerShare).div(collateralPrice);
				repayment = debtWithPenalty;
			} else {
				mainToLiquidator = mainAmount;
				colToLiquidator = colAmount;
				repayment = collateralPrice;
			}
		} else {
			mainToLiquidator = mainAmount;
			colToLiquidator = colAmount;
		}

		const mainAmountInPositionAfterLiquidation = await this.vault.collaterals(this.mainCollateral.address, positionOwner);
		const colAmountInPositionAfterLiquidation = await this.vault.colToken(this.mainCollateral.address, positionOwner);
		const usdpDebt = await this.vault.getTotalDebt(this.mainCollateral.address, positionOwner);

		const usdpLiquidatorBalance = await this.usdp.balanceOf(liquidator);
		const colLiquidatorBalance = await this.col.balanceOf(liquidator);
		const mainLiquidatorBalance = await this.mainCollateral.balanceOf(liquidator);
		const colOwnerBalanceAfter = await this.col.balanceOf(positionOwner);
		const mainOwnerBalanceAfter = await this.mainCollateral.balanceOf(positionOwner);

		expect(mainAmountInPositionAfterLiquidation).to.be.bignumber.equal(new BN('0'));
		expect(colAmountInPositionAfterLiquidation).to.be.bignumber.equal(new BN('0'));
		expect(usdpDebt).to.be.bignumber.equal(new BN('0'));
		expect(usdpLiquidatorBalance).to.be.bignumber.equal(initialLiquidatorUsdpBalance.sub(repayment));
		expect(colLiquidatorBalance).to.be.bignumber.equal(colToLiquidator);
		expect(mainLiquidatorBalance).to.be.bignumber.equal(mainToLiquidator);
		expect(colOwnerBalanceAfter.sub(colOwnerBalanceBefore)).to.be.bignumber.equal(colToOwner);
		expect(mainOwnerBalanceAfter.sub(mainOwnerBalanceBefore)).to.be.bignumber.equal(mainToOwner);
	})
});
