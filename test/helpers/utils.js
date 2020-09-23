const Vault = artifacts.require('Vault');
const Parameters = artifacts.require('Parameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const UniswapOracle = artifacts.require('ChainlinkedUniswapOracleMock');
const ChainlinkAggregator = artifacts.require('ChainlinkAggregatorMock');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManagerStandard = artifacts.require('VaultManagerStandard');
const VaultManagerUniswap = artifacts.require('VaultManagerUniswap');
const Liquidator = artifacts.require('LiquidatorUniswap');
const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode } = require('./deployUtils');
const BN = web3.utils.BN;
const { expect } = require('chai');

const MAX_UINT = new BN('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');

async function expectRevert(promise, expectedError) {
	try {
		await promise;
	} catch (error) {
		if (error.message.indexOf(expectedError) === -1) {
			// When the exception was a revert, the resulting string will include only
			// the revert reason, otherwise it will be the type of exception (e.g. 'invalid opcode')
			const actualError = error.message.replace(
				/Returned error: VM Exception while processing transaction: (revert )?/,
				'',
			);
			expect(actualError).to.equal(expectedError, 'Wrong kind of exception received');
		}
		return;
	}

	expect.fail('Expected an exception but none was received');
}

module.exports = context => {
	const poolDeposit = async (token, amount, decimals) => {
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
	};

	const approveCollaterals = async(main, mainAmount, colAmount) => {
		await main.approve(context.vault.address, mainAmount);
		return context.col.approve(context.vault.address, colAmount);
	};

	const spawn = async(main, mainAmount, colAmount, usdpAmount) => {
		await approveCollaterals(main, mainAmount, colAmount);
		return context.vaultManagerUniswap.spawn(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const spawnEth = async(mainAmount, colAmount, usdpAmount) => {
		await context.col.approve(context.vault.address, colAmount);
		return context.vaultManagerUniswap.spawn_Eth(
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // COL price proof
			{ value: mainAmount	}
		);
	};

	const join = async(main, mainAmount, colAmount, usdpAmount) => {
		await main.approve(context.vault.address, mainAmount);
		await context.col.approve(context.vault.address, colAmount);
		return context.vaultManagerUniswap.depositAndBorrow(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const liquidate = (main, user) => {
		return context.liquidator.liquidate(
			main.address,
			user,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const exit = async(main, mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswap.withdrawAndRepay(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const repayAllAndWithdraw = async(main, user) => {
		const totalDebt = await context.vault.getTotalDebt(main.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		const mainAmount = await context.vault.collaterals(main.address, user);
		const colAmount = await context.vault.colToken(main.address, user);
		return context.vaultManagerStandard.repayAllAndWithdraw(main.address, mainAmount, colAmount);
	};

	const withdrawAndRepay = async(main, mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswap.withdrawAndRepay(
			main.address,
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const repay = async(main, user, usdpAmount) => {
		const totalDebt = await context.vault.getTotalDebt(main.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		return context.vaultManagerStandard.repay(
			main.address,
			usdpAmount,
		);
	};

	const withdrawAndRepayEth = async(mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswap.withdrawAndRepay_Eth(
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const withdrawAndRepayCol = async(main, mainAmount, colAmount, usdpAmount) => {
		await context.col.approve(context.vault.address, MAX_UINT);
		return context.vaultManagerUniswap.withdrawAndRepayUsingCol(
			main.address,
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const repayUsingCol = async(main, usdpAmount) => {
		await context.col.approve(context.vault.address, MAX_UINT);
		return context.vaultManagerUniswap.repayUsingCol(
			main.address,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const repayAllAndWithdrawEth = async(user) => {
		const mainAmount = await context.vault.collaterals(context.weth.address, user);
		const colAmount = await context.vault.colToken(context.weth.address, user);
		return context.vaultManagerStandard.repayAllAndWithdraw_Eth(mainAmount, colAmount);
	};

	const updatePrice = async() => {
		return context.chainlinkAggregator.setPrice(await context.chainlinkAggregator.latestAnswer());
	}

	const deploy = async() => {
		context.col = await DummyToken.new("Unit Protocol Token", "COL", 18, ether('1000000'));
		context.weth = await WETH.new();
		context.mainCollateral = await DummyToken.new("STAKE clone", "STAKE", 18, ether('1000000'));

		await context.weth.deposit({ value: ether('4') });
		const uniswapFactoryAddr = await deployContractBytecode(UniswapV2FactoryDeployCode, context.deployer, web3);
		context.uniswapFactory = await IUniswapV2Factory.at(uniswapFactoryAddr);

		context.chainlinkAggregator = await ChainlinkAggregator.new();

		context.uniswapOracle = await UniswapOracle.new(
			context.uniswapFactory.address,
			context.weth.address,
			context.chainlinkAggregator.address,
		);

		const parametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.usdp = await USDP.new(parametersAddr);
		const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.parameters = await Parameters.new(vaultAddr, context.foundation);
		context.vault = await Vault.new(context.parameters.address, context.col.address, context.usdp.address, context.weth.address);
		context.liquidator = await Liquidator.new(context.vault.address, context.uniswapOracle.address, context.liquidationSystem);
		context.vaultManagerUniswap = await VaultManagerUniswap.new(
			context.vault.address,
			context.parameters.address,
			context.uniswapOracle.address,
		);
		context.vaultManagerStandard = await VaultManagerStandard.new(
			context.vault.address,
			context.parameters.address,
		);

		context.uniswapRouter = await UniswapV2Router02.new(context.uniswapFactory.address, context.weth.address);

		await context.weth.approve(context.uniswapRouter.address, ether('100'));

		// Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
		await poolDeposit(context.col, 250);

		// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
		await poolDeposit(context.mainCollateral, 125);

		await context.parameters.setVaultAccess(context.vaultManagerUniswap.address, true);
		await context.parameters.setVaultAccess(context.liquidator.address, true);
		await context.parameters.setVaultAccess(context.vaultManagerStandard.address, true);

		await context.parameters.setCollateral(
			context.mainCollateral.address,
			'0', // stability fee
			'0', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			ether('100000'), // debt limit
			[1], // enabled oracles
			3,
			5,
		);

		await context.parameters.setCollateral(
			context.weth.address,
			'0', // stability fee
			'0', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			ether('100000'), // debt limit
			[1], // enabled oracles
			3,
			5,
		);

		await context.parameters.setInitialCollateralRatio(context.col.address, 67);
		await context.parameters.setLiquidationRatio(context.col.address, 68);
	};

	return {
		poolDeposit,
		spawn,
		spawnEth,
		approveCollaterals,
		join,
		liquidate,
		exit,
		repayAllAndWithdraw,
		repayAllAndWithdrawEth,
		withdrawAndRepay,
		withdrawAndRepayEth,
		withdrawAndRepayCol,
		deploy,
		updatePrice,
		repay,
		repayUsingCol,
		expectRevert,
	}
}
