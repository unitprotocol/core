const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');
const utils = require('./helpers/utils');
const { expectRevert } = require('openzeppelin-test-helpers');

contract('VaultManager', function([
	deployer,
	liquidationSystem,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = deployer;
		this.liquidationSystem = liquidationSystem;
		await this.utils.deploy();
		// const tokenPrice = await this.uniswapOracle.tokenToUsd(this.mainCollateral.address, '100');
		// console.log(tokenPrice.toString());
	});

	describe('Optimistic cases', function() {
		it('Should spawn position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('4');
			const usdpAmount = ether('20');

			const { logs } = await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Spawn', {
				collateral: this.mainCollateral.address,
				user: deployer,
				oracleType: '1',
			});

			expectEvent.inLogs(logs, 'Join', {
				collateral: this.mainCollateral.address,
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

		it('Should close position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('5');
			const usdpAmount = ether('20');

			await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.repayAndWithdraw(this.mainCollateral, deployer);
			expectEvent.inLogs(logs, 'Destroy', {
				collateral: this.mainCollateral.address,
				user: deployer,
			});

			expectEvent.inLogs(logs, 'Exit', {
				collateral: this.mainCollateral.address,
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

		it('Should deposit collaterals to position and mint USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('5');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.mainCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.join(this.mainCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Update', {
				collateral: this.mainCollateral.address,
				user: deployer,
			});

			expectEvent.inLogs(logs, 'Join', {
				collateral: this.mainCollateral.address,
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
				const tx = this.vaultManager.spawn(
					this.mainCollateral.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					'1', // oracle type: Uniswap
				);
				await this.utils.expectRevert(tx, "USDP: SPAWNED_POSITION");
			})

			it('Reverts wrong oracle type', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
				const tx = this.vaultManager.spawn(
					this.mainCollateral.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					'2', // wrong oracle type
				);
				await this.utils.expectRevert(tx, "USDP: WRONG_ORACLE_TYPE");
			})

			it('Reverts non valuable tx', async function() {
				const mainAmount = ether('0');
				const colAmount = ether('0');
				const usdpAmount = ether('0');

				await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
				const tx = this.vaultManager.spawn(
					this.mainCollateral.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					'1', // oracle type: Uniswap
				);
				await this.utils.expectRevert(tx, "USDP: USELESS_TX");
			})

			describe('Reverts when collateralization is incorrect', function() {
				it('Not enough COL token on collateral', async function() {
					let mainAmount = ether('100');
					let colAmount = ether('0');
					const usdpAmount = ether('20');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
					const tx = this.vaultManager.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						'1', // oracle type: Uniswap
					);
					await this.utils.expectRevert(tx, "USDP: INCORRECT_COLLATERALIZATION");
				})
				it('Not enough main collateral', async function() {
					let mainAmount = ether('0');
					let colAmount = ether('100');
					const usdpAmount = ether('20');

					await this.utils.approveCollaterals(this.mainCollateral, mainAmount, colAmount);
					const tx = this.vaultManager.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						'1', // oracle type: Uniswap
					);
					await this.utils.expectRevert(tx, "USDP: INCORRECT_COLLATERALIZATION");
				})

				it('Reverts when main collateral is not approved', async function() {
					const mainAmount = ether('100');
					const colAmount = ether('5');
					const usdpAmount = ether('20');

					const tx = this.vaultManager.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						'1', // oracle type: Uniswap
					);
					await this.utils.expectRevert(tx, "TRANSFER_FAILURE");
				})

				it('Reverts when COL token is not approved', async function() {
					const mainAmount = ether('100');
					const colAmount = ether('5');
					const usdpAmount = ether('20');

					await this.mainCollateral.approve(this.vault.address, mainAmount);

					const tx = this.vaultManager.spawn(
						this.mainCollateral.address,
						mainAmount, // main
						colAmount, // COL
						usdpAmount,	// USDP
						'1', // oracle type: Uniswap
					);
					await this.utils.expectRevert(tx, "TRANSFER_FAILURE");
				})
			})
		})

		describe('Join', function () {
			it('Reverts non-existent position', async function() {
				const mainAmount = ether('100');
				const colAmount = ether('5');
				const usdpAmount = ether('20');

				const tx = this.vaultManager.join(this.mainCollateral.address, mainAmount, colAmount, usdpAmount);
				await this.utils.expectRevert(tx, "USDP: POSITION_DOES_NOT_EXIST");
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
				await this.utils.expectRevert(tx, "USDP: UNDERCOLLATERALIZED_POSITION");
			})
		})
	})
});
