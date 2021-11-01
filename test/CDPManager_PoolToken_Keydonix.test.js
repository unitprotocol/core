const {
	expectEvent,
	ether,
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const increaseTime = require('./helpers/timeTravel');
const time = require('./helpers/time');

[
	'keydonixPoolToken',
].forEach(oracleMode =>
	contract(`CDPManager with ${oracleMode} oracle`, function([
		deployer,
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
						'mainAmount': new BN('10000000000'),
						'usdpAmount': new BN('2000000000'),
						'usdpBorrowFee': new BN('24680000'), // see BASE_BORROW_FEE from utils.js
					},
					{
						'name': 'small usdp value, borrow fee trimmed',
						'mainAmount': new BN('1000'),
						'usdpAmount': new BN('200'),
						'usdpBorrowFee': new BN('2')
					},
					{
						'name': 'small usdp value, borrow fee trimmed to zero ',
						'mainAmount': new BN('100'),
						'usdpAmount': new BN('20'),
						'usdpBorrowFee': new BN('0')
					}
				].forEach(function (test_params) {
					it('Should spawn position: ' + test_params['name'], async function () {

						const mainAmount = test_params['mainAmount'];
						const usdpAmount = test_params['usdpAmount'];
						const usdpBorrowFee = test_params['usdpBorrowFee'];

						const {logs} = await this.utils.join(this.poolToken, mainAmount, usdpAmount);

						expectEvent.inLogs(logs, 'Join', {
							asset: this.poolToken.address,
							owner: deployer,
							main: mainAmount,
							usdp: usdpAmount,
						});

						const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
						const usdpBalance = await this.usdp.balanceOf(deployer);
						const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

						expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
						expect(usdpBalance).to.be.bignumber.equal(this.INITIAL_USDP_AMOUNT.add(usdpAmount).sub(usdpBorrowFee));
						expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee);
					})
				})
			})

			describe('Repay & withdraw', function() {
				it('Should repay the debt of a position and withdraw collaterals', async function() {

					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.join(this.poolToken, mainAmount, usdpAmount);

					const { logs } = await this.utils.repayAllAndWithdraw(this.poolToken, deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.poolToken.address,
						owner: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				})

				it('Should accumulate fee when stability fee above zero and make repayment', async function() {
					await this.vaultParameters.setStabilityFee(this.poolToken.address, 3000); // 3% st. fee
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.join(this.poolToken, mainAmount, usdpAmount);

					const timeStart = await time.latest();

					await increaseTime(3600 * 24);

					const accumulatedDebt = await this.vault.getTotalDebt(this.poolToken.address, deployer);

          const expectedDebt = usdpAmount.mul(new BN('3000')).mul((await time.latest()).sub(timeStart)).div(new BN(365*24*60*60)).div(new BN('100000')).add(usdpAmount);

					expect(accumulatedDebt.div(new BN(10 ** 12))).to.be.bignumber.equal(
						expectedDebt.div(new BN(10 ** 12))
					);

					// get some usdp to cover fee
          await this.usdp.setMinter(deployer, true);
          await this.usdp.mint(deployer, ether('2'))

          await this.utils.updatePrice();

					// repay debt partially
					await this.utils.repay(this.poolToken, usdpAmount.div(new BN(2)));

					const accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.poolToken.address, deployer);

					expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
						expectedDebt.div(new BN(2)).div(new BN(10 ** 12))
					);

					await this.utils.repayAllAndWithdraw(this.poolToken, deployer);
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.join(this.poolToken, mainAmount, usdpAmount);

					const mainToWithdraw = new BN('50');
					const usdpToRepay = new BN('10');

					const { logs } = await this.utils.exit(this.poolToken, mainToWithdraw, usdpToRepay);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.poolToken.address,
						owner: deployer,
						main: mainToWithdraw,
						usdp: usdpToRepay,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
					const usdpInPosition = await this.vault.debts(this.poolToken.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToRepay));
				})
			})

			it('Should deposit collaterals to position and mint USDP', async function () {
				let mainAmount = new BN('100');
				let usdpAmount = new BN('20');
				const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

				await this.utils.join(this.poolToken, mainAmount, usdpAmount);

				const { logs } = await this.utils.join(this.poolToken, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.poolToken.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);
				const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));

				let mintedUsdp = this.INITIAL_USDP_AMOUNT.mul(new BN(2));
				expect(usdpBalance).to.be.bignumber.equal(mintedUsdp.add(usdpAmount.mul(new BN(2))).sub(usdpBorrowFee.mul(new BN(2))));
				expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
				let mainAmount = new BN('100');
				let usdpAmount = new BN('20');
				const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount).mul(new BN(2))

				await this.utils.join(this.poolToken, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

				const usdpSupplyBefore = await this.usdp.totalSupply();

				await this.utils.exit(this.poolToken, mainAmount, usdpAmount);

				const usdpSupplyAfter = await this.usdp.totalSupply();

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(usdpBalance).to.be.bignumber.equal(this.INITIAL_USDP_AMOUNT.add(usdpAmount).sub(usdpBorrowFee));
				expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
			})
		});

		describe('Pessimistic cases', function() {
			describe('Spawn', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = new BN('0');
					const usdpAmount = new BN('0');

					const tx = this.utils.join(
						this.poolToken,
						mainAmount, // main
						usdpAmount,	// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				describe('Reverts when collateralization is incorrect', function() {
					it('Not enough main collateral', async function() {
						let mainAmount = new BN('0');
						const usdpAmount = new BN('20');

						const tx = this.utils.join(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
						);
						await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
					})

					it('Reverts when main collateral is not approved', async function() {
						const mainAmount = new BN('100');
						const usdpAmount = new BN('20');

						const tx = this.utils.join(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
							{ noApprove: true }
						);
						await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
					})

					it('Reverts when borrow fee is not approved', async function() {
						const mainAmount = new BN('1000');
						const usdpAmount = new BN('200');

						const tx = this.utils.join(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								approveUSDP: new BN(0)
							}
						);
						await this.utils.expectRevert(tx, "BORROW_FEE_NOT_APPROVED");
					})

					it('Reverts when not enough borrow fee is approved', async function() {
						const mainAmount = new BN('1000');
						const usdpAmount = new BN('200');
						const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

						const tx = this.utils.join(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
							{
								approveUSDP: usdpBorrowFee.sub(new BN(1))
							}
						);
						await this.utils.expectRevert(tx, "BORROW_FEE_NOT_APPROVED");
					})
				})
			})

			describe('Exit', function () {
				it('Reverts non valuable tx', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.join(this.poolToken, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.poolToken, 0, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when position state after exit becomes undercollateralized', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.join(this.poolToken, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.poolToken, mainAmount, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
			})
		})
	})
);
