const {
	expectEvent,
	ether,
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const increaseTime = require("./helpers/timeTravel");

[
	'chainlinkMainAsset',
	'sushiswapKeep3rMainAsset',
	'uniswapKeep3rMainAsset'
].forEach(oracleMode =>
	contract(`CDPManager with ${oracleMode} oracle wrapper`, function([
		deployer,
		liquidator,
	]) {
		// deploy & initial settings
		beforeEach(async function() {
			this.utils = utils(this, oracleMode);
			this.deployer = deployer;
			await this.utils.deploy();
		});

		describe('Optimistic cases', function() {
			describe('Spawn', function() {
				[
					{
						'name': 'big enough usdp value',
						'usdpAmount': ether('20'),
						'usdpBorrowFee': new BN('246000000000000000'), // see BASE_BORROW_FEE from utils.js
					},
					{
						'name': 'small usdp value, borrow fee trimmed',
						'usdpAmount': new BN('200'),
						'usdpBorrowFee': new BN('2')
					},
					{
						'name': 'small usdp value, borrow fee trimmed to zero ',
						'usdpAmount': new BN('20'),
						'usdpBorrowFee': new BN('0')
					}
				].forEach(function (test_params) {
					it('Should spawn position: ' + test_params['name'], async function () {
						const mainAmount = ether('100');
						const usdpAmount = test_params['usdpAmount'];
						const usdpBorrowFee = test_params['usdpBorrowFee'];

						const {logs} = await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

						expectEvent.inLogs(logs, 'Join', {
							asset: this.mainCollateral.address,
							owner: deployer,
							main: mainAmount,
							usdp: usdpAmount,
						});

						const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
						const usdpBalance = await this.usdp.balanceOf(deployer);
						const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

						expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
						expect(usdpBalance).to.be.bignumber.equal(usdpAmount.sub(usdpBorrowFee));
						expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee);
					})
				})

				it('Should spawn position using ETH', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');
					const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

					const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

					const { logs } = await this.utils.joinEth(mainAmount, usdpAmount);

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
					expect(usdpBalance).to.be.bignumber.equal(usdpAmount.sub(usdpBorrowFee));
				})
			})

			describe('Repay & withdraw', function() {
				it('Should repay the debt of a position and withdraw collaterals', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const { logs } = await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.mainCollateral.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
					const usdpBalance = await this.usdp.balanceOf(deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(usdpBalance).to.be.bignumber.equal(new BN(0));
				})

				it('repay all without withdrawal and then with withdrawal with stability fee', async function() {
					await this.vaultParameters.setStabilityFee(this.mainCollateral.address, 3000); // 3% st. fee
					// get some usdp to cover fee
					await this.usdp.setMinter(deployer, true);
					await this.usdp.mint(deployer, ether('2'));

					await this.usdp.approve(this.vault.address, ether('1000'));

					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					const collateralBalanceBefore = await this.mainCollateral.balanceOf(deployer);

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					await increaseTime(3600 * 24);

					const collateralBalanceAfter = await this.mainCollateral.balanceOf(deployer);

					await this.vaultManager.repayAll(this.mainCollateral.address, false);

					expect(await this.vault.getFee(this.mainCollateral.address, deployer)).to.be.bignumber.equal(new BN(0))
					expect(await this.vault.debts(this.mainCollateral.address, deployer)).to.be.bignumber.equal(new BN(0))

					expect(await this.mainCollateral.balanceOf(deployer)).to.be.bignumber.equal(collateralBalanceAfter)

					const usdpBalanceAfterFirstRepay = await this.usdp.balanceOf(deployer)

					await this.vaultManager.repayAll(this.mainCollateral.address, true);

					expect(await this.mainCollateral.balanceOf(deployer)).to.be.bignumber.equal(collateralBalanceBefore)
					expect(await this.usdp.balanceOf(deployer)).to.be.bignumber.equal(usdpBalanceAfterFirstRepay)
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const mainToWithdraw = ether('50');
					const usdpToRepay = ether('2.5');

					const { logs } = await this.utils.exit(this.mainCollateral, mainToWithdraw, usdpToRepay);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.mainCollateral.address,
						owner: deployer,
						main: mainToWithdraw,
						usdp: usdpToRepay,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
					const usdpInPosition = await this.vault.debts(this.mainCollateral.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToRepay));
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially using ETH', async function() {
					const mainAmount = ether('10');
					const usdpAmount = ether('1');

					await this.utils.joinEth(mainAmount, usdpAmount);

					const mainToWithdraw = ether('1');
					const usdpToRepay = ether('0.5');

					const wethBalanceBefore = await balance.current(this.weth.address);

					const { logs } = await this.utils.exitEth(mainToWithdraw, usdpToRepay);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						owner: deployer,
						main: mainToWithdraw,
						usdp: usdpToRepay,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
					const usdpInPosition = await this.vault.debts(this.weth.address, deployer);
					const wethBalanceAfter = await balance.current(this.weth.address);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToRepay));
					expect(wethBalanceBefore.sub(wethBalanceAfter)).to.be.bignumber.equal(mainToWithdraw);
				})

				it('Should repay the debt of a position and withdraw collaterals using ETH', async function() {
					const mainAmount = ether('2');
					const usdpAmount = ether('1');

					await this.utils.joinEth(mainAmount, usdpAmount);

					const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

					const { logs } = await this.utils.repayAllAndWithdrawEth(deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.weth.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);
					const usdpBalance = await this.usdp.balanceOf(deployer);
					const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);

					expect(usdpBalance).to.be.bignumber.equal(new BN(0));
					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
				})
			})

			it('Should deposit collaterals to position and mint USDP', async function() {
				let mainAmount = ether('100');
				let usdpAmount = ether('20');
				const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

				await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

				const { logs } = await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.mainCollateral.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);
				const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)).sub(usdpBorrowFee.mul(new BN(2))));
				expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function() {
				let mainAmount = ether('100');
				let usdpAmount = ether('20');
				const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount).mul(new BN(2))

				await this.utils.join(this.mainCollateral, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

				const usdpSupplyBefore = await this.usdp.totalSupply();

				await this.utils.exit(this.mainCollateral, mainAmount, usdpAmount);

				const usdpSupplyAfter = await this.usdp.totalSupply();

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.sub(usdpBorrowFee));
				expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
			})

		});

		describe('Pessimistic cases', function() {
			describe('Spawn', function() {

				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('0');
					const usdpAmount = ether('0');

					await this.mainCollateral.approve(this.vault.address, mainAmount);
					const tx = this.utils.join(
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

						await this.mainCollateral.approve(this.vault.address, mainAmount);
						const tx = this.utils.join(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
						);
						await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
					})

					it('Reverts when main collateral is not approved', async function() {
						const mainAmount = ether('100');
						const usdpAmount = ether('20');

						const tx = this.utils.join(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								noApprove: true
							},
						);
						await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
					})

					it('Reverts when borrow fee is not approved', async function() {
						const mainAmount = ether('100');
						const usdpAmount = ether('20');

						const tx = this.utils.join(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								approveUSDP: new BN(0)
							},
						);
						await this.utils.expectRevert(tx, "BORROW_FEE_NOT_APPROVED");
					})

					it('Reverts when not enough borrow fee is approved', async function() {
						const mainAmount = ether('100');
						const usdpAmount = ether('20');
						const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

						const tx = this.utils.join(
							this.mainCollateral,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								approveUSDP: usdpBorrowFee.sub(new BN(1))
							},
						);
						await this.utils.expectRevert(tx, "BORROW_FEE_NOT_APPROVED");
					})
				})
			})

			describe('Exit', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when position becomes undercollateralized', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, mainAmount, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
			})

			it('Should fail to trigger liquidation of collateralized position', async function () {
				const positionOwner = deployer
				const mainAmount = ether('60');
				const usdpAmount = ether('70');

				/*
				 * Spawned position params:
				 * collateral value = 60 * 2 = 120$
				 * utilization percent = 70 / 120 = 58.3%
				 */
				await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

				const tx = this.utils.triggerLiquidation(this.mainCollateral, positionOwner, liquidator);
				await this.utils.expectRevert(tx, "Unit Protocol: SAFE_POSITION");
			})

		})
	})
)
