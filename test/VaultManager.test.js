const {
	expectEvent,
	ether,
	expectRevert,
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const increaseTime = require('./helpers/timeTravel');
const time = require('./helpers/time');

contract('VaultManager', function([
	deployer,
	liquidationSystem,
	foundation,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = deployer;
		this.liquidationSystem = liquidationSystem;
		this.foundation = foundation;
		await this.utils.deploy();
	});

	describe('Optimistic cases', function() {
		describe('Spawn', function() {
			it('Should spawn position', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('4');
				const usdpAmount = ether('20');

				const { logs } = await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.mainCollateral.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			})

			it('Should spawn position using ETH', async function() {
				const mainAmount = ether('2');
				const colAmount = ether('1');
				const usdpAmount = ether('1');

				const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

				const { logs } = await this.utils.spawnEth(mainAmount, colAmount, usdpAmount);

				expectEvent.inLogs(logs, 'Join', {
					asset: this.weth.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);
				expect(wethInVaultAfter.sub(wethInVaultBefore)).to.be.bignumber.equal(mainAmount);

				const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.weth.address, deployer);
				const usdpBalance = await this.usdp.balanceOf(deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
				expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			})
		})

		describe('Repay & withdraw', function() {
			it('Should repay the debt of a position and withdraw collaterals', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				const { logs } = await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.mainCollateral.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
			})

			it('Should accumulate fee when stability is fee above zero and make repayment', async function() {
				await this.parameters.setStabilityFee(this.mainCollateral.address, 3000); // 3% st. fee
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

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

				// repay debt partially using COL
				await this.utils.repayUsingCol(this.mainCollateral, usdpAmount.div(new BN(4)));
				accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.mainCollateral.address, deployer);
				expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.sub(expectedDebt.mul(new BN(3)).div(new BN(4))).div(new BN(10 ** 12))
				);

				const colBalanceBeforeRepayment = await this.col.balanceOf(deployer);
				// withdraw&repay debt partially using COL
				await this.utils.withdrawAndRepayCol(this.mainCollateral, ether('50'), ether('0'), usdpAmount.div(new BN(8)));

				expectedDebt = usdpAmount.mul(new BN('3000')).mul((await time.latest()).sub(timeStart)).div(new BN(365*24*60*60)).div(new BN('100000')).add(usdpAmount);
				accumulatedDebtAfterRepayment = await this.vault.getTotalDebt(this.mainCollateral.address, deployer);

				// expect to have approx 1/8 from total accumulated debt
				expect(accumulatedDebtAfterRepayment.div(new BN(10 ** 12))).to.be.bignumber.equal(
					expectedDebt.div(new BN(8)).div(new BN(10 ** 12))
				);

				const colBalanceAfterRepayment = await this.col.balanceOf(deployer);

				// in testing preset 1 COL = 1$
				const expectedColBalanceDiff = expectedDebt.sub(usdpAmount).div(new BN(8));
				const colBalanceDiff = colBalanceBeforeRepayment.sub(colBalanceAfterRepayment);

				expect(colBalanceDiff).to.be.bignumber.equal(expectedColBalanceDiff);

				await this.utils.repayAllAndWithdraw(this.mainCollateral, deployer);
			})

			it('Should partially repay the debt of a position and withdraw collaterals partially', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				const mainToWithdraw = ether('50');
				const colToWithdraw = ether('2.5');
				const usdpToWithdraw = ether('2.5');

				const { logs } = await this.utils.withdrawAndRepay(this.mainCollateral, mainToWithdraw, colToWithdraw, usdpToWithdraw);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.mainCollateral.address,
					user: deployer,
					main: mainToWithdraw,
					col: colToWithdraw,
					usdp: usdpToWithdraw,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);
				const usdpInPosition = await this.vault.debts(this.mainCollateral.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount.sub(colToWithdraw));
				expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
			})

			it('Should partially repay the debt of a position and withdraw collaterals partially using ETH', async function() {
				const mainAmount = ether('2');
				const colAmount = ether('1');
				const usdpAmount = ether('1');

				await this.utils.spawnEth(mainAmount, colAmount, usdpAmount);

				const mainToWithdraw = ether('1');
				const colToWithdraw = ether('0.5');
				const usdpToWithdraw = ether('0.5');

				const wethBalanceBefore = await balance.current(this.weth.address);

				const { logs } = await this.utils.withdrawAndRepayEth(mainToWithdraw, colToWithdraw, usdpToWithdraw);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.weth.address,
					user: deployer,
					main: mainToWithdraw,
					col: colToWithdraw,
					usdp: usdpToWithdraw,
				});

				const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.weth.address, deployer);
				const usdpInPosition = await this.vault.debts(this.weth.address, deployer);
				const wethBalanceAfter = await balance.current(this.weth.address);

				expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.sub(mainToWithdraw));
				expect(colAmountInPosition).to.be.bignumber.equal(colAmount.sub(colToWithdraw));
				expect(usdpInPosition).to.be.bignumber.equal(usdpAmount.sub(usdpToWithdraw));
				expect(wethBalanceBefore.sub(wethBalanceAfter)).to.be.bignumber.equal(mainToWithdraw);
			})

			it('Should repay the debt of a position and withdraw collaterals using ETH', async function() {
				const mainAmount = ether('2');
				const colAmount = ether('1');
				const usdpAmount = ether('1');

				await this.utils.spawnEth(mainAmount, colAmount, usdpAmount);

				const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

				const { logs } = await this.utils.repayAllAndWithdrawEth(deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.weth.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);

				const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.weth.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
			})

			it('Should repay the debt of a position and withdraw collaterals using ETH repaying fee in COL', async function() {
				const mainAmount = ether('2');
				const colAmount = ether('1');
				const usdpAmount = ether('1');

				await this.utils.spawnEth(mainAmount, colAmount, usdpAmount);

				const wethInVaultBefore = await this.weth.balanceOf(this.vault.address);

				const { logs } = await this.utils.repayAllAndWithdrawEth(deployer);

				expectEvent.inLogs(logs, 'Exit', {
					asset: this.weth.address,
					user: deployer,
					main: mainAmount,
					col: colAmount,
					usdp: usdpAmount,
				});

				const wethInVaultAfter = await this.weth.balanceOf(this.vault.address);

				const mainAmountInPosition = await this.vault.collaterals(this.weth.address, deployer);
				const colAmountInPosition = await this.vault.colToken(this.weth.address, deployer);

				expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
				expect(wethInVaultBefore.sub(wethInVaultAfter)).to.be.bignumber.equal(mainAmount);
			})
		})

		it('Should deposit collaterals to position and mint USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('5');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.join(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			expectEvent.inLogs(logs, 'Join', {
				asset: this.mainCollateral.address,
				user: deployer,
				main: mainAmount,
				col: colAmount,
				usdp: usdpAmount,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
		})

		it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('5');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.mainCollateral, mainAmount.mul(new BN(2)), colAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.mainCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.mainCollateral.address, deployer);
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
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);
				await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
				const tx = this.vaultManagerUniswap.spawn(
					this.mainCollateral.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "USDP: SPAWNED_POSITION");
			})

			it('Reverts non valuable tx', async function() {
				const mainAmount = ether('0');
				const colAmount = ether('0');
				const usdpAmount = ether('0');

				await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
				const tx = this.vaultManagerUniswap.spawn(
					this.mainCollateral.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "USDP: ZERO_BORROWING");
			})

			describe('Reverts when collateralization is incorrect', function() {
				it('Not enough COL token on collateral', async function() {
					let mainAmount = ether('100');
					let colAmount = ether('0');
					const usdpAmount = ether('20');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
					const tx = this.vaultManagerUniswap.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "USDP: UNDERCOLLATERALIZED");
				})
				it('Not enough main collateral', async function() {
					let mainAmount = ether('0');
					let colAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
					const tx = this.vaultManagerUniswap.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "USDP: UNDERCOLLATERALIZED");
				})

				it('Reverts when main collateral is not approved', async function() {
					const mainAmount = ether('100');
					const colAmount = ether('5');
					const usdpAmount = ether('20');

					const tx = this.vaultManagerUniswap.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "TRANSFER_FAILURE");
				})

				it('Reverts when COL token is not approved', async function() {
					const mainAmount = ether('100');
					const colAmount = ether('5');
					const usdpAmount = ether('20');

					await this.mainCollateral.approve(this.vault.address, mainAmount);

					const tx = this.vaultManagerUniswap.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // main price proof
						['0x', '0x', '0x', '0x'], // COL price proof
					);
					await this.utils.expectRevert(tx, "TRANSFER_FAILURE");
				})
			})
		})

		describe('Join', function () {
			it('Reverts non-spawned position', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				const tx = this.vaultManagerUniswap.depositAndBorrow(
					this.mainCollateral.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
				await this.utils.expectRevert(tx, "USDP: NOT_SPAWNED_POSITION");
			})
		})

		describe('Exit', function () {
			it('Reverts non valuable tx', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.mainCollateral, 0, 0, 0);
				await this.utils.expectRevert(tx, "USDP: USELESS_TX");
			})

			it('Reverts when specified repayment amount is more than the accumulated debt', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.mainCollateral, mainAmount, colAmount, usdpAmount.add(new BN(1)));
				await expectRevert.unspecified(tx);
			})

			it('Reverts when position becomes undercollateralized', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

				const tx = this.utils.exit(this.mainCollateral, mainAmount, 0, 0);
				await this.utils.expectRevert(tx, "USDP: UNDERCOLLATERALIZED");
			})
		})
	})
});
