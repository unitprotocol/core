const {
	expectEvent,
	ether,
	expectRevert,
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

	contract(`VaultManager with SushiSwap Keep3r oracle wrapper for main asset`, function([
		deployer,
		foundation,
	]) {
		// deploy & initial settings
		beforeEach(async function() {
			this.utils = utils(this, 'sushiswapKeep3rMainAsset');
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
						user: deployer,
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
						user: deployer,
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
						user: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const mainToWithdraw = ether('50');
					const colToWithdraw = ether('2.5');
					const usdpToWithdraw = ether('2.5');

					const { logs } = await this.utils.withdrawAndRepay(this.mainCollateral, mainToWithdraw, colToWithdraw, usdpToWithdraw);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.mainCollateral.address,
						user: deployer,
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
					const colToWithdraw = ether('0.5');
					const usdpToWithdraw = ether('0.5');

					const wethBalanceBefore = await balance.current(this.weth.address);

					const { logs } = await this.utils.withdrawAndRepayEth(mainToWithdraw, colToWithdraw, usdpToWithdraw);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						user: deployer,
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
						user: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
				})

				it('Should repay the debt of a position and withdraw collaterals using ETH repaying fee in COL', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');

					await this.utils.spawnEth(mainAmount, usdpAmount);

					const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

					const { logs } = await this.utils.repayAllAndWithdrawEth(deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						user: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
				})
			})

			it('Should deposit collaterals to position and mint USDP', async function() {
				let mainAmount = ether('100');
				let usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

				const { logs } = await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.mainCollateral.address,
					user: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function() {
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
				it('Reverts pre-existent position', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);
					await this.mainCollateral.approve(this.vault.address, mainAmount);
					const tx = this.utils.spawn(
						this.mainCollateral,
						mainAmount, // main
						usdpAmount// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: SPAWNED_POSITION");
				})

				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('0');
					const usdpAmount = ether('0');

					await this.mainCollateral.approve(this.vault.address, mainAmount);
					const tx = this.utils.spawn(
						this.mainCollateral,
						mainAmount, // main
						usdpAmount,	// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: ZERO_BORROWING");
				})

				describe('Reverts when collateralization is incorrect', function() {
					it('Not enough main collateral', async function() {
						let mainAmount = ether('0');
						const usdpAmount = ether('20');

						await this.mainCollateral.approve(this.vault.address, mainAmount);
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

			describe('Join', function() {
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

			describe('Exit', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, 0, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when specified repayment amount is more than the accumulated debt', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.spawn(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, mainAmount, usdpAmount.add(new BN(1)));
					await expectRevert.unspecified(tx);
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
