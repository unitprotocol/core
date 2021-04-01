const {
	expectEvent,
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');

[
	'chainlinkPoolToken',
	// 'sushiswapKeep3rPoolToken',
	// 'uniswapKeep3rPoolToken'
].forEach(oracleMode =>
	contract(`CDPManager with ${oracleMode} oracle`, function([
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

					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					const { logs } = await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

					expectEvent.inLogs(logs, 'Join', {
						asset: this.poolToken.address,
						user: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
					const usdpBalance = await this.usdp.balanceOf(deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
					expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
					expect(await this.cdpRegistry.isListed(this.poolToken.address, deployer)).to.equal(true);
				})
			})

			describe('Repay & withdraw', function() {
				it('Should repay the debt of a position and withdraw collaterals', async function() {

					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

					const { logs } = await this.utils.repayAllAndWithdraw(this.poolToken, deployer);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.poolToken.address,
						user: deployer,
						main: mainAmount,
						usdp: usdpAmount,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
					expect(await this.cdpRegistry.isListed(this.poolToken.address, deployer)).to.equal(false);
				})

				it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

					const mainToWithdraw = new BN('50');
					const usdpToRepay = new BN('10');

					const { logs } = await this.utils.withdrawAndRepay(this.poolToken, mainToWithdraw, usdpToRepay);

					expectEvent.inLogs(logs, 'Exit', {
						asset: this.poolToken.address,
						user: deployer,
						main: mainToWithdraw,
						usdp: usdpToRepay,
					});

					const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
					const usdpInPosition = await this.vault.debts(this.poolToken.address, deployer);

					expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
					expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToRepay));
				})
			})

			it('Should deposit collaterals to position and mint USDP', async function() {
				let mainAmount = new BN('100');
				let usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

				const { logs } = await this.utils.join(this.poolToken, mainAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.poolToken.address,
					user: deployer,
					main: mainAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
			})

			it('Should withdraw collaterals from position and repay (burn) USDP', async function() {
				let mainAmount = new BN('100');
				let usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

				const usdpSupplyBefore = await this.usdp.totalSupply();

				await this.utils.exit(this.poolToken, mainAmount, usdpAmount);

				const usdpSupplyAfter = await this.usdp.totalSupply();

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
				expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
			})
		});

		describe('Pessimistic cases', function() {
			describe('Spawn', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = new BN('0');
					const usdpAmount = new BN('0');

					const tx = this.utils.spawn(
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

						const tx = this.utils.spawn(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
						);
						await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
					})

					it('Reverts when main collateral is not approved', async function() {
						const mainAmount = new BN('100');
						const usdpAmount = new BN('20');

						const tx = this.utils.spawn(
							this.poolToken,
							mainAmount, // main
							usdpAmount,	// USDP
							{ noApprove: true }
						);
						await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
					})
				})
			})

			describe('Exit', function() {
				it('Reverts non valuable tx', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.poolToken, 0, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
				})

				it('Reverts when position state after exit becomes undercollateralized', async function() {
					const mainAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.spawn(this.poolToken, mainAmount, usdpAmount);

					const tx = this.utils.exit(this.poolToken, mainAmount, 0);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
			})
		})
	})
)
