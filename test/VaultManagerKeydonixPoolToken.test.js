const {
	expectEvent,
	expectRevert,
} = require('openzeppelin-test-helpers');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const increaseTime = require('./helpers/timeTravel');
const time = require('./helpers/time');

contract('VaultManagerKeydonixPoolToken', function([
	deployer,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this, 'keydonixPoolToken');
		this.deployer = deployer;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	describe('Optimistic cases', function() {
		describe('Spawn', function() {
			it('Should spawn position', async function() {

				const mainAmount = new BN('100');
				const colAmount = new BN('4');
				const usdpAmount = new BN('20');

				const { logs } = await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.poolToken.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.poolToken.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			})
		})

		describe('Repay & withdraw', function() {
			it('Should repay the debt of a position and withdraw collaterals', async function() {

				const mainAmount = new BN('100');
				const colAmount = new BN('4');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const { logs } = await this.utils.repayAllAndWithdraw(this.poolToken, deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.poolToken.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.poolToken.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
			})

			it('Should accumulate fee when stability is fee above zero and make repayment', async function() {
				await this.vaultParameters.setStabilityFee(this.poolToken.address, 3000); // 3% st. fee
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const timeStart = await time.latest();

				await increaseTime(3600 * 24);

				const accumulatedDebt = await this.vault.getTotalDebt(this.poolToken.address, deployer);

				let expectedDebt = usdpAmount.mul(new BN('3000')).mul((await time.latest()).sub(timeStart)).div(new BN(365*24*60*60)).div(new BN('100000')).add(usdpAmount);

				expect(accumulatedDebt.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.div(new BN(10 ** 12))
				);

				// get some usdp to cover fee
				await this.utils.updatePrice();
				await this.utils.spawnEth(new BN('2'), new BN('1'), new BN('2'));

				// repay debt partially
				await this.utils.repay(this.poolToken, deployer, usdpAmount.div(new BN(2)));

				let accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.poolToken.address, deployer);
				expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.div(new BN(2)).div(new BN(10 ** 12))
				);

				// repay debt partially using COL
				await this.utils.repayUsingCol(this.poolToken, usdpAmount.div(new BN(4)));
				accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.poolToken.address, deployer);
				expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.sub(expectedDebt.mul(new BN(3)).div(new BN(4))).div(new BN(10 ** 12))
				);

				const colBalanceBeforeRepayment = await this.col.balanceOf(deployer);
				// withdraw&repay debt partially using COL
				await this.utils.withdrawAndRepayCol(this.poolToken, new BN('50'), new BN('0'), usdpAmount.div(new BN(8)));

				expectedDebt = usdpAmount.mul(new BN('3000')).mul((await time.latest()).sub(timeStart)).div(new BN(365*24*60*60)).div(new BN('100000')).add(usdpAmount);
				accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.poolToken.address, deployer);

				// expect to have approx 1/8 from total accumulated debt
				expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.div(new BN(8)).div(new BN(10 ** 12))
				);

				const colBalanceAfterRepayment = await this.col.balanceOf(deployer);

				// in testing preset 1 COL = 1$
				const expectedColBalanceDiff = expectedDebt.sub(usdpAmount).div(new BN(8));
				const colBalanceDiff = colBalanceBeforeRepayment.sub(colBalanceAfterRepayment);

				expect(colBalanceDiff).to.be.bignumber.equal(expectedColBalanceDiff);

				await this.utils.repayAllAndWithdraw(this.poolToken, deployer);
			})

			it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const mainToWithdraw = new BN('50');
				const colToWithdraw = new BN('2');
				const usdpToRepay = new BN('10');

				const { logs } = await this.utils.withdrawAndRepay(this.poolToken, mainToWithdraw, colToWithdraw, usdpToRepay);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.poolToken.address,
					user: deployer,
					main: mainToWithdraw,
					col: colToWithdraw,
					usdp: usdpToRepay,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.poolToken.address, deployer);
				const usdpInPosition = await this.vault.debts(this.poolToken.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount.sub(colToWithdraw));
				expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToRepay));
			})
		})

		it('Should deposit collaterals to position and mint USDP', async function () {
			let mainAmount = new BN('100');
			let colAmount = new BN('5');
			let usdpAmount = new BN('20');

			await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.join(this.poolToken, mainAmount, colAmount, usdpAmount);

			expectEvent.inLogs(logs, 'Join', {
				asset: this.poolToken.address,
				user: deployer,
				main: mainAmount,
				col: colAmount,
				usdp: usdpAmount,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.poolToken.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
		})

		it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
			let mainAmount = new BN('100');
			let colAmount = new BN('5');
			let usdpAmount = new BN('20');

			await this.utils.spawn(this.poolToken, mainAmount.mul(new BN(2)), colAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.poolToken, mainAmount, colAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.poolToken.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.poolToken.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
		})
	});

	describe('Pessimistic cases', function() {
		describe('Spawn', function() {
			it('Reverts pre-existent position', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);
				await this.utils.approveCollaterals(this.poolToken, mainAmount, colAmount);
				const tx = this.vaultManagerKeydonixPoolToken.spawn(
					this.poolToken.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "Unit Protocol: SPAWNED_POSITION");
			})

			it('Reverts non valuable tx', async function() {
				const mainAmount = new BN('0');
				const colAmount = new BN('0');
				const usdpAmount = new BN('0');

				await this.utils.approveCollaterals(this.poolToken, mainAmount, colAmount);
				const tx = this.vaultManagerKeydonixPoolToken.spawn(
					this.poolToken.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "Unit Protocol: ZERO_BORROWING");
			})

			describe('Reverts when collateralization is incorrect', function() {
				it('Not enough COL token on collateral', async function() {
					let mainAmount = new BN('100');
					let colAmount = new BN('0');
					const usdpAmount = new BN('20');

					await this.utils.approveCollaterals(this.poolToken, mainAmount, colAmount);
					const tx = this.vaultManagerKeydonixPoolToken.spawn(
						this.poolToken.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})
				it('Not enough main collateral', async function() {
					let mainAmount = new BN('0');
					let colAmount = new BN('100');
					const usdpAmount = new BN('20');

					await this.utils.approveCollaterals(this.poolToken, mainAmount, colAmount);
					const tx = this.vaultManagerKeydonixPoolToken.spawn(
						this.poolToken.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
				})

				it('Reverts when main collateral is not approved', async function() {
					const mainAmount = new BN('100');
					const colAmount = new BN('5');
					const usdpAmount = new BN('20');

					const tx = this.vaultManagerKeydonixPoolToken.spawn(
						this.poolToken.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
				})

				it('Reverts when COL token is not approved', async function() {
					const mainAmount = new BN('100');
					const colAmount = new BN('5');
					const usdpAmount = new BN('20');

					await this.poolToken.approve(this.vault.address, mainAmount);

					const tx = this.vaultManagerKeydonixPoolToken.spawn(
						this.poolToken.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "TRANSFER_FROM_FAILED");
				})
			})
		})

		describe('Join', function () {
			it('Reverts non-spawned position', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				const tx = this.vaultManagerKeydonixPoolToken.depositAndBorrow(
					this.poolToken.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "Unit Protocol: NOT_SPAWNED_POSITION");
			})
		})

		describe('Exit', function () {
			it('Reverts non valuable tx', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.poolToken, 0, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: USELESS_TX");
			})

			it('Reverts when specified repayment amount is greater than the accumulated debt', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.poolToken, mainAmount, colAmount, usdpAmount.add(new BN(1)));
				await expectRevert.unspecified(tx);
			})

			it('Reverts when position state after exit becomes undercollateralized', async function() {
				const mainAmount = new BN('100');
				const colAmount = new BN('5');
				const usdpAmount = new BN('20');

				await this.utils.spawn(this.poolToken, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.poolToken, mainAmount, 0, 0);
				await this.utils.expectRevert(tx, "Unit Protocol: UNDERCOLLATERALIZED");
			})
		})
	})
});
