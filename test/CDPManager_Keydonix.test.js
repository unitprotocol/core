const {
	expectEvent,
	ether,
} = require('openzeppelin-test-helpers');
const chai = require('chai');
const { solidity } = require("ethereum-waffle");
chai.use(solidity);
const { expect } = chai;
const BN = web3.utils.BN;
const utils = require('./helpers/utils');
const increaseTime = require('./helpers/timeTravel');
const { BigNumber } = require("ethers");

[
	'keydonixMainAsset',
].forEach(oracleMode =>
	contract(`CDPManager with ${oracleMode} oracle wrapper`, function([
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
						'usdpAmount': ether('20'),
						'usdpBorrowFee': new BN('246800000000000000'), // see BASE_BORROW_FEE from utils.js
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
						expect(usdpBalance).to.be.bignumber.equal(this.INITIAL_USDP_AMOUNT.add(usdpAmount).sub(usdpBorrowFee));
						expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee);
					})
				})
			})

			describe('Repay & withdraw', function() {
				it('Should accumulate fee when stability fee above zero and make repayment', async function() {
					const stFee = new BN(3000)
				  await this.vaultParameters.setStabilityFee(this.mainCollateral.address, stFee); // 3% st. fee
					const mainAmount = ether('100');

					// borrow 20
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					await increaseTime(3600 * 24);

					const accumulatedFee = await this.vault.getFee(this.mainCollateral.address, deployer);

					const expectedFee = usdpAmount.mul(stFee).div(new BN(365)).div(new BN(1e5))

          expect(BigNumber.from(accumulatedFee.toString())).to.be.closeTo(BigNumber.from(expectedFee.toString()), 10n ** 12n);

          const repayment = usdpAmount.div(new BN(2))
          // get some usdp to cover fee
					await this.usdp.setMinter(deployer, true);
					await this.usdp.mint(deployer, ether('2'));

          await this.utils.updatePrice();

					// repay debt partially
					await this.utils.repay(this.mainCollateral, repayment);

					const accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.mainCollateral.address, deployer);
					expect(BigNumber.from(accumulatedDebtAfterRepayment.toString())).to.be.closeTo(BigNumber.from(usdpAmount.add(expectedFee).sub(repayment).toString()), 10n ** 12n);

					await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const mainToWithdraw = ether('50');
					const usdpToWithdraw = ether('2.5');

					const { logs } = await this.utils.exit(this.mainCollateral, mainToWithdraw, usdpToWithdraw);

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
			})

			it('Should deposit collaterals to position and mint USDP', async function () {
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

				let mintedUsdp = this.INITIAL_USDP_AMOUNT.mul(new BN(2));
				expect(usdpBalance).to.be.bignumber.equal(mintedUsdp.add(usdpAmount.mul(new BN(2))).sub(usdpBorrowFee.mul(new BN(2))));
				expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
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
				expect(usdpBalance).to.be.bignumber.equal(this.INITIAL_USDP_AMOUNT.add(usdpAmount).sub(usdpBorrowFee));
				expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
			})
		});

		describe('Pessimistic cases', function() {
			describe('Spawn', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('0');
					const usdpAmount = ether('0');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount);
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

						await this.utils.approveCollaterals(this.mainCollateral, mainAmount);
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

			describe('Exit', function () {
				it('Reverts non valuable tx', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, 0, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when position becomes undercollateralized', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.join(this.mainCollateral, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.mainCollateral, mainAmount, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
			})
		})
	})
);
