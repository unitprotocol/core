const {
	expectEvent,
	ether,
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const increaseTime = require('./helpers/timeTravel');
const time = require('./helpers/time');

[
	'keydonixMainAsset',
].forEach(oracleMode =>
	contract(`CDPManager with ${oracleMode} oracle wrapper`, function([
		deployer,
		foundation,
	]) {
		// deploy & initial settings
		beforeEach(async function() {
			this.utils = utils(this, oracleMode);
			this.deployer = deployer;
			this.foundation = foundation;
			await this.utils.deploy();
		});

		describe('Optimistic cases', function() {
			describe('Spawn', function() {
				it('Should spawn position', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					const { logs } = await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					expectEvent.inLogs(logs, 'Join', {
						asset: this.mainCollateral.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
					const usdpBalance = await this.usdp.balanceOf(deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
					expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
				})

				it('Should spawn position using ETH', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');

					const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

					const { logs } = await this.utils.spawnEth(mainAmount, usdpAmount);

					expectEvent.inLogs(logs, 'Join', {
						asset: this.weth.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);
					expect(wethInVaultAfter.sub(wethInVaultBefore)).to.be.bignumber.equal(mainAmount);

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
					const usdpBalance = await this.usdp.balanceOf(deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
					expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
				})
			})

			describe('Repay & withdraw', function() {
				it('Should repay the debt of a position and withdraw collaterals', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const { logs } = await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.mainCollateral.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				})

				it('Should accumulate fee when stability fee above zero and make repayment', async function() {
					await this.vaultParameters.setStabilityFee(this.mainCollateral.address, 3000); // 3% st. fee
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const timeStart = await time.latest();

					await increaseTime(3600 * 24);

					const accumulatedDebt = await this.vault.getTotalDebt(this.mainCollateral.address, deployer);

					let expectedDebt = usdpAmount.mul(new BN('3000')).mul((await time.latest()).sub(timeStart)).div(new BN(365*24*60*60)).div(new BN('100000')).add(usdpAmount);

					expect(accumulatedDebt.div(new BN(10 ** 12))).to.be.bignumber.equal(
						expectedDebt.div(new BN(10 ** 12))
					);

					// get some usdp to cover fee
					await this.utils.updatePrice();
					await this.utils.spawnEth(ether('2'), ether('1'), ether('2'));

					// repay debt partially
					await this.utils.repay(this.mainCollateral, deployer, usdpAmount.div(new BN(2)));

					let accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.mainCollateral.address, deployer);
					expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
						expectedDebt.div(new BN(2)).div(new BN(10 ** 12))
					);

					await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const mainToWithdraw = ether('50');
					const usdpToWithdraw = ether('2.5');

					const { logs } = await this.utils.withdrawAndRepay(this.mainCollateral, mainToWithdraw, usdpToWithdraw);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.mainCollateral.address,
						owner: deployer,
						main: mainToWithdraw,
						usdp: usdpToWithdraw,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
					const usdpInPosition = await this.vault.debts(this.mainCollateral.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially using ETH', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');

					await this.utils.spawnEth(mainAmount, usdpAmount);

					const mainToWithdraw = ether('1');
					const usdpToWithdraw = ether('0.5');

					const wethBalanceBefore = await balance.current(this.weth.address);

					const { logs } = await this.utils.withdrawAndRepayEth(mainToWithdraw, usdpToWithdraw);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						owner: deployer,
						main: mainToWithdraw,
						usdp: usdpToWithdraw,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
					const usdpInPosition = await this.vault.debts(this.weth.address, deployer);
					const wethBalanceAfter = await balance.current(this.weth.address);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
					expect(wethBalanceBefore.sub(wethBalanceAfter)).to.be.bignumber.equal(mainToWithdraw);
				})

				it('Should repay the debt of a position and withdraw collaterals using ETH', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');

					await this.utils.spawnEth(mainAmount, usdpAmount);

					const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

					const { logs } = await this.utils.repayAllAndWithdrawEth(deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
				})
			})

			it('Should deposit collaterals to position and mint USDP', async function () {
				let mainAmount = ether('100');
				let usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

				const { logs } = await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.mainCollateral.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
				let mainAmount = ether('100');
				let usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

				const usdpSupplyBefore = await this.usdp.totalSupply();

				await this.utils.exit(this.mainCollateral, mainAmount, usdpAmount);

				const usdpSupplyAfter = await this.usdp.totalSupply();

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
				expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
			})
		});

		describe('Pessimistic cases', function() {
			describe('Spawn', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('0');
					const usdpAmount = ether('0');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount);
					const tx = this.utils.spawn(
						this.mainCollateral,
						mainAmount, // main
						usdpAmount,	// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				describe('Reverts when collateralization is incorrect', function() {
					it('Not enough main collateral', async function() {
						let mainAmount = ether('0');
						const usdpAmount = ether('20');

						await this.utils.approveCollaterals(this.mainCollateral, mainAmount);
						const tx = this.utils.spawn(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
						);
						await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
					})

					it('Reverts when main collateral is not approved', async function() {
						const mainAmount = ether('100');
						const usdpAmount = ether('20');

						const tx = this.utils.spawn(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								noApprove: true
							},
						);
						await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
					})
				})
			})

			describe('Join', function () {
				it('Reverts non-spawned position', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					const tx = this.utils.join(
						this.mainCollateral,
						mainAmount,
						usdpAmount,
					);
					await this.utils.expectRevert(tx, "Unit Protocol: NOT_SPAWNED_POSITION");
				})
			})

			describe('Exit', function () {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, 0, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when position becomes undercollateralized', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, mainAmount, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
			})
		})
	})
);
