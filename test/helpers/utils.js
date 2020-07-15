const Vault = artifacts.require('Vault');
const Parameters = artifacts.require('Parameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const UniswapOracle = artifacts.require('UniswapOracle');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManager = artifacts.require('VaultManager');
const Liquidator = artifacts.require('Liquidator');
const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode } = require('./deployUtils');
const BN = web3.utils.BN;

module.exports = context =>
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
		liquidate: (main, user) => {
			return context.liquidator.liquidate(
				main.address,
				user,
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
		},
		deploy: async() => {
			context.col = await DummyToken.new("COL clone", "COL", 18, ether('1000000'));
			context.dai = await DummyToken.new("DAI clone", "DAI", 18, ether('1000000'));
			context.usdc = await DummyToken.new("USDC clone", "USDC", 6, String(10000000 * 10 ** 6));
			context.weth = await WETH.new();
			context.someCollateral = await DummyToken.new("Example collateral token", "ECT", 18, ether('1000000'));

			await context.weth.deposit({ value: ether('4') });
			const uniswapFactoryAddr = await deployContractBytecode(UniswapV2FactoryDeployCode, context.deployer);
			context.uniswapFactory = await IUniswapV2Factory.at(uniswapFactoryAddr);

			await context.uniswapFactory.createPair(context.dai.address, context.weth.address);
			await context.uniswapFactory.createPair(context.usdc.address, context.weth.address);

			context.uniswapOracle = await UniswapOracle.new(
				context.uniswapFactory.address,
				context.dai.address,
				context.usdc.address,
				context.weth.address,
			);

			const parametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
			context.usdp = await USDP.new(parametersAddr);
			const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
			context.parameters = await Parameters.new(vaultAddr);
			context.vault = await Vault.new(context.parameters.address, context.col.address, context.usdp.address);
			context.liquidator = await Liquidator.new(context.parameters.address, context.vault.address, context.uniswapOracle.address, context.col.address, context.liquidationSystem);
			context.vaultManager = await VaultManager.new(
				context.vault.address,
				context.liquidator.address,
				context.parameters.address,
				context.uniswapOracle.address,
				context.col.address
			);

			context.uniswapRouter = await UniswapV2Router02.new(context.uniswapFactory.address, context.weth.address);

			await context.weth.approve(context.uniswapRouter.address, ether('100'));

			// Add liquidity to DAI/WETH pool; rate = 200 DAI/ETH
			await context.utils.poolDeposit(context.dai, 200);

			// Add liquidity to USDC/WETH pool
			await context.utils.poolDeposit(context.usdc, 300, 6);

			// Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
			await context.utils.poolDeposit(context.col, 250);

			// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
			await context.utils.poolDeposit(context.someCollateral, 125);

			await context.parameters.setOracleType('1', true);
			await context.parameters.setVaultAccess(context.vaultManager.address, true);
			await context.parameters.setVaultAccess(context.liquidator.address, true);
			await context.parameters.setCollateral(
				context.someCollateral.address,
				'0', // stability fee
				'0', // liquidation fee
				'150', // min collateralization
				ether('100000'), // debt limit
			);
		}
	}
}
