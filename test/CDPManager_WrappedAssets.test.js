const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers')
const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

contract('CDPManager with wrapped assets', function([deployer]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'curveLP')
		this.deployer = deployer
		await this.utils.deploy()
	});

	describe('Optimistic cases', function() {
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
			it('Should spawn a position: ' + test_params['name'], async function () {
				const mainAmount = ether('100');
				const usdpAmount = test_params['usdpAmount'];
				const usdpBorrowFee = test_params['usdpBorrowFee'];

				const {logs} = await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.wrappedAsset.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const assetAmountInPosition = await this.vault.collaterals(this.wrappedAsset.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);
				const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

				expect(assetAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.sub(usdpBorrowFee));
				expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee);
			})
		})

		describe('Repay & withdraw', function() {
			it('Should repay the debt of a position and withdraw collaterals', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

				const { logs } = await this.utils.repayAllAndWithdraw(this.wrappedAsset, deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.wrappedAsset.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.wrappedAsset.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(usdpBalance).to.be.bignumber.equal(new BN(0));
			})

			it('Should partially repay the debt of a position and withdraw the part of the collateral', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

				const mainToWithdraw = ether('50');
				const usdpToWithdraw = ether('2.5');

				const { logs } = await this.utils.exit(this.wrappedAsset, mainToWithdraw, usdpToWithdraw);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.wrappedAsset.address,
					owner: deployer,
					main: mainToWithdraw,
					usdp: usdpToWithdraw,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.wrappedAsset.address, deployer);
				const usdpInPosition = await this.vault.debts(this.wrappedAsset.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
				expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
			})

		})

		it('Should deposit collaterals to position and mint USDP', async function() {
			let mainAmount = ether('100');
			let usdpAmount = ether('20');
			const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount)

			await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

			const { logs } = await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

			expectEvent.inLogs(logs, 'Join', {
				asset: this.wrappedAsset.address,
				owner: deployer,
				main: mainAmount,
				usdp: usdpAmount,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.wrappedAsset.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);
			const borrowFeeReceiverUsdpBalance = await this.usdp.balanceOf(this.utils.BORROW_FEE_RECEIVER_ADDRESS);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)).sub(usdpBorrowFee.mul(new BN(2))));
			expect(borrowFeeReceiverUsdpBalance).to.be.bignumber.equal(usdpBorrowFee.mul(new BN(2)));
		})

		it('Should withdraw collateral from a position and repay (burn) USDP', async function() {
			let mainAmount = ether('100');
			let usdpAmount = ether('20');
			const usdpBorrowFee = this.utils.calcBorrowFee(usdpAmount).mul(new BN(2))

			await this.utils.join(this.wrappedAsset, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.wrappedAsset, mainAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.wrappedAsset.address, deployer);
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

				await this.wrappedAsset.approve(this.vault.address, mainAmount);
				const tx = this.utils.join(
					this.wrappedAsset,
					mainAmount, // main
					usdpAmount,	// USDP
				);
				await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
			})

			describe('Reverts when collateralization is incorrect', function() {
				it('Not enough main collateral', async function() {
					let mainAmount = ether('0');
					const usdpAmount = ether('20');

					await this.wrappedAsset.approve(this.vault.address, mainAmount);
					const tx = this.utils.join(
						this.wrappedAsset,
						mainAmount, // main
						usdpAmount,	// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})

				it('Reverts when main collateral is not approved', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					const tx = this.utils.join(
						this.wrappedAsset,
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
						this.wrappedAsset,
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
						this.wrappedAsset,
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

				await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

				const tx = this.utils.exit(this.wrappedAsset, 0, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
			})

			it('Reverts when position becomes undercollateralized', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.wrappedAsset, mainAmount, usdpAmount);

				const tx = this.utils.exit(this.wrappedAsset, mainAmount, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
			})
		})
	})

});
