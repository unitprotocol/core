const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers')
const BN = web3.utils.BN
const { expect } = require('chai')
const utils = require('./helpers/utils')

contract('CDPManager with bearing assets', function([deployer, foundation]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'bearingAssetSimple')
		this.deployer = deployer
		this.foundation = foundation;
		await this.utils.deploy()

		// make 1 bearing asset equal to 2 main tokens
		const supply = await this.bearingAsset.totalSupply()
		await this.mainCollateral.transfer(this.bearingAsset.address, supply.mul(new BN('2')))
	});

	describe('Optimistic cases', function() {
		it('Should spawn a position', async function() {
			const mainAmount = ether('100');
			const usdpAmount = ether('20');

			const { logs } = await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

			expectEvent.inLogs(logs, 'Join', {
				asset: this.bearingAsset.address,
				owner: deployer,
				main: mainAmount,
				usdp: usdpAmount,
			});

			const assetAmountInPosition = await this.vault.collaterals(this.bearingAsset.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(assetAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
		})

		describe('Repay & withdraw', function() {
			it('Should repay the debt of a position and withdraw collaterals', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

				const { logs } = await this.utils.repayAllAndWithdraw(this.bearingAsset, deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.bearingAsset.address,
					owner: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.bearingAsset.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
			})

			it('Should partially repay the debt of a position and withdraw the part of the collateral', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

				const mainToWithdraw = ether('50');
				const usdpToWithdraw = ether('2.5');

				const { logs } = await this.utils.exit(this.bearingAsset, mainToWithdraw, usdpToWithdraw);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.bearingAsset.address,
					owner: deployer,
					main: mainToWithdraw,
					usdp: usdpToWithdraw,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.bearingAsset.address, deployer);
				const usdpInPosition = await this.vault.debts(this.bearingAsset.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
				expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
			})

		})

		it('Should deposit collaterals to position and mint USDP', async function() {
			let mainAmount = ether('100');
			let usdpAmount = ether('20');

			await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

			const { logs } = await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

			expectEvent.inLogs(logs, 'Join', {
				asset: this.bearingAsset.address,
				owner: deployer,
				main: mainAmount,
				usdp: usdpAmount,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.bearingAsset.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
		})

		it('Should withdraw collateral from a position and repay (burn) USDP', async function() {
			let mainAmount = ether('100');
			let usdpAmount = ether('20');

			await this.utils.join(this.bearingAsset, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.bearingAsset, mainAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.bearingAsset.address, deployer);
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

				await this.bearingAsset.approve(this.vault.address, mainAmount);
				const tx = this.utils.join(
					this.bearingAsset,
					mainAmount, // main
					usdpAmount,	// USDP
				);
				await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
			})

			describe('Reverts when collateralization is incorrect', function() {
				it('Not enough main collateral', async function() {
					let mainAmount = ether('0');
					const usdpAmount = ether('20');

					await this.bearingAsset.approve(this.vault.address, mainAmount);
					const tx = this.utils.join(
						this.bearingAsset,
						mainAmount, // main
						usdpAmount,	// USDP
					);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})

				it('Reverts when main collateral is not approved', async function() {
					const mainAmount = ether('100');
					const usdpAmount = ether('20');

					const tx = this.utils.join(
						this.bearingAsset,
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

		describe('Exit', function() {
			it('Reverts non valuable tx', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

				const tx = this.utils.exit(this.bearingAsset, 0, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
			})

			it('Reverts when position becomes undercollateralized', async function() {
				const mainAmount = ether('100');
				const usdpAmount = ether('20');

				await this.utils.join(this.bearingAsset, mainAmount, usdpAmount);

				const tx = this.utils.exit(this.bearingAsset, mainAmount, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
			})
		})
	})

});
