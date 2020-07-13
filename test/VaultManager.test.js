const {
	expectEvent,
	ether
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const { calculateAddressAtNonce, deployContractBytecode } = require('./helpers/deployUtils');
const BN = web3.utils.BN;
const { expect } = require('chai');

const Vault = artifacts.require('Vault');
const Parameters = artifacts.require('Parameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const UniswapOracle = artifacts.require('UniswapOracle');
const UniswapV2FactoryDeployCode = require('./helpers/UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManager = artifacts.require('VaultManager');
const Liquidator = artifacts.require('Liquidator');


const utils = context =>
{
	return {
		poolDeposit: async (token, amount, decimals) => {
			amount = decimals ? String(amount * 10 ** decimals) : ether(amount.toString());
			amount = new BN(amount).div(new BN((10 ** 6).toString()));
			const block = await web3.eth.getBlock('latest');
			const time = new BN(block.timestamp);
			await token.approve(context.uniswapRouter.address, amount);
			await context.uniswapRouter.addLiquidity(
				token.address,
				context.weth.address,
				amount,
				ether('1').div(new BN((10 ** 6).toString())),
				amount,
				ether('1').div(new BN((10 ** 6).toString())),
				context.deployer,
				time.add(new BN('100')),
			);
		},
		spawn: async(main, mainAmount, colAmount, usdpAmount) => {
			await main.approve(context.vault.address, mainAmount);
			await context.col.approve(context.vault.address, colAmount);
			return context.vaultManager.spawn(
				main.address,
				mainAmount, // main
				colAmount, // COL
				usdpAmount,	// USDP
				'1', // oracle type: Uniswap
			);
		},
		join: async(main, mainAmount, colAmount, usdpAmount) => {
			await main.approve(context.vault.address, mainAmount);
			await context.col.approve(context.vault.address, colAmount);
			return context.vaultManager.join(
				main.address,
				mainAmount, // main
				colAmount, // COL
				usdpAmount,	// USDP
			);
		},
		exit: async(main, mainAmount, colAmount, usdpAmount) => {
			return context.vaultManager.exit(
				main.address,
				mainAmount, // main
				colAmount, // COL
				usdpAmount,	// USDP
			);
		},
		repayAndWithdraw: async(main, user) => {
			const mainAmount = await context.vault.collaterals(main.address, user);
			const colAmount = await context.vault.colToken(main.address, user);
			return context.vaultManager.repayAll(main.address, mainAmount, colAmount);
		}
	}
}

contract('VaultManager', function([
	deployer,
	liquidationSystem,
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.utils = utils(this);
		this.deployer = deployer;

		this.col = await DummyToken.new("COL clone", "COL", 18, ether('1000000'));
		this.dai = await DummyToken.new("DAI clone", "DAI", 18, ether('1000000'));
		this.usdc = await DummyToken.new("USDC clone", "USDC", 6, String(10000000 * 10 ** 6));
		this.weth = await WETH.new();
		this.someCollateral = await DummyToken.new("Example collateral token", "ECT", 18, ether('1000000'));

		await this.weth.deposit({ value: ether('4') });
		const uniswapFactoryAddr = await deployContractBytecode(UniswapV2FactoryDeployCode, deployer);
		this.uniswapFactory = await IUniswapV2Factory.at(uniswapFactoryAddr);

		await this.uniswapFactory.createPair(this.dai.address, this.weth.address);
		await this.uniswapFactory.createPair(this.usdc.address, this.weth.address);

		this.uniswapOracle = await UniswapOracle.new(
			this.uniswapFactory.address,
			this.dai.address,
			this.usdc.address,
			this.weth.address,
		);

		const parametersAddr = calculateAddressAtNonce(deployer, await web3.eth.getTransactionCount(deployer) + 1);
		this.usdp = await USDP.new(parametersAddr);
		const vaultAddr = calculateAddressAtNonce(deployer, await web3.eth.getTransactionCount(deployer) + 1);
		this.parameters = await Parameters.new(vaultAddr);
		this.vault = await Vault.new(this.parameters.address, this.col.address, this.usdp.address);
		this.liquidator = await Liquidator.new(this.parameters.address, this.vault.address, this.uniswapOracle.address, this.col.address, liquidationSystem);
		this.vaultManager = await VaultManager.new(
			this.vault.address,
			this.liquidator.address,
			this.parameters.address,
			this.uniswapOracle.address,
			this.col.address
		);

		this.uniswapRouter = await UniswapV2Router02.new(this.uniswapFactory.address, this.weth.address);

		await this.weth.approve(this.uniswapRouter.address, ether('100'));

		// Add liquidity to DAI/WETH pool; rate = 200 DAI/ETH
		await this.utils.poolDeposit(this.dai, 200);

		// Add liquidity to USDC/WETH pool
		await this.utils.poolDeposit(this.usdc, 300, 6);

		// Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
		await this.utils.poolDeposit(this.col, 250);

		// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
		await this.utils.poolDeposit(this.someCollateral, 125);

		await this.parameters.setOracleType('1', true);
		await this.parameters.setVaultAccess(this.vaultManager.address, true);
		await this.parameters.setCollateral(
			this.someCollateral.address,
			'0', // stability fee
			'0', // liquidation fee
			'150', // min collateralization
			ether('100000'), // debt limit
		);
		// const tokenPrice = await this.uniswapOracle.tokenToUsd(this.someCollateral.address, '100');
	});

	describe('Optimistic cases', function() {
		it('Should spawn position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('20');
			const usdpAmount = ether('20');

			const { logs } = await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Spawn', {
				collateral: this.someCollateral.address,
				user: deployer,
				oracleType: '1',
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
		})

		it('Should close position', async function () {
			const mainAmount = ether('100');
			const colAmount = ether('20');
			const usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.repayAndWithdraw(this.someCollateral, deployer);
			expectEvent.inLogs(logs, 'Destroy', {
				collateral: this.someCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(new BN(0));
			expect(colAmountInPosition).to.be.bignumber.equal(new BN(0));
		})

		it('Should deposit collaterals to position and mint USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('20');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const { logs } = await this.utils.join(this.someCollateral, mainAmount, colAmount, usdpAmount);
			expectEvent.inLogs(logs, 'Update', {
				collateral: this.someCollateral.address,
				user: deployer,
			});

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount.mul(new BN(2)));
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount.mul(new BN(2)));
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount.mul(new BN(2)));
		})

		it('Should withdraw collaterals from position and repay (burn) USDP', async function () {
			let mainAmount = ether('100');
			let colAmount = ether('20');
			let usdpAmount = ether('20');

			await this.utils.spawn(this.someCollateral, mainAmount.mul(new BN(2)), colAmount.mul(new BN(2)), usdpAmount.mul(new BN(2)));

			const usdpSupplyBefore = await this.usdp.totalSupply();

			await this.utils.exit(this.someCollateral, mainAmount, colAmount, usdpAmount);

			const usdpSupplyAfter = await this.usdp.totalSupply();

			const mainAmountInPosition = await this.vault.collaterals(this.someCollateral.address, deployer);
			const colAmountInPosition = await this.vault.colToken(this.someCollateral.address, deployer);
			const usdpBalance = await this.usdp.balanceOf(deployer);

			expect(mainAmountInPosition).to.be.bignumber.equal(mainAmount);
			expect(colAmountInPosition).to.be.bignumber.equal(colAmount);
			expect(usdpBalance).to.be.bignumber.equal(usdpAmount);
			expect(usdpSupplyAfter).to.be.bignumber.equal(usdpSupplyBefore.sub(usdpAmount));
		})
	});
});
