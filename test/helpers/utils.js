const Vault = artifacts.require('Vault');
const VaultParameters = artifacts.require('VaultParameters');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const UniswapOracleMainAsset = artifacts.require('ChainlinkedUniswapOracleMainAsset_Mock');
const UniswapOraclePoolToken = artifacts.require('ChainlinkedUniswapOraclePoolToken_Mock');
const ChainlinkAggregator = artifacts.require('ChainlinkAggregator_Mock');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const IUniswapV2Pair = artifacts.require('IUniswapV2PairFull');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManagerStandard = artifacts.require('VaultManagerStandard');
const VaultManagerUniswapMainAsset = artifacts.require('VaultManagerUniswapMainAsset');
const VaultManagerUniswapPoolToken = artifacts.require('VaultManagerUniswapPoolToken');
const LiquidatorMainAsset = artifacts.require('LiquidationTriggerUniswapMainAsset');
const LiquidatorPoolToken = artifacts.require('LiquidationTriggerUniswapPoolToken');
const LiquidationAuction01 = artifacts.require('LiquidationAuction01');
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
		const ethUnitsPerDeposit = ether('1').div(new BN((10 ** 6)));
		const block = await web3.eth.getBlock('latest');
		const time = new BN(block.timestamp);
		await token.approve(context.uniswapRouter.address, amount);
		await context.uniswapRouter.addLiquidity(
			token.address,
			context.weth.address,
			amount,
			ethUnitsPerDeposit,
			amount,
			ethUnitsPerDeposit,
			context.deployer,
			time.add(new BN('100')),
		);
	};

	const approveCollaterals = async(main, mainAmount, colAmount, from = context.deployer) => {
		await main.approve(context.vault.address, mainAmount, { from });
		return context.col.approve(context.vault.address, colAmount, { from });
	};

	const getPoolToken = async(mainAddress) => {
		const poolAddress = await context.uniswapFactory.getPair(context.weth.address, mainAddress);
		return IUniswapV2Pair.at(poolAddress);
	};

	const spawn = async(main, mainAmount, colAmount, usdpAmount, from = context.deployer) => {
		await approveCollaterals(main, mainAmount, colAmount, from);
		return context.vaultManagerUniswapMainAsset.spawn(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
			{ from },
		);
	};

	const spawn_Pool = async(main, mainAmount, colAmount, usdpAmount) => {
		await approveCollaterals(main, mainAmount, colAmount);
		return context.vaultManagerUniswapPoolToken.spawn(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // underlying token price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const spawnEth = async(mainAmount, colAmount, usdpAmount) => {
		await context.col.approve(context.vault.address, colAmount);
		return context.vaultManagerUniswapMainAsset.spawn_Eth(
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // COL price proof
			{ value: mainAmount	}
		);
	};

	const join = async(main, mainAmount, colAmount, usdpAmount) => {
		await main.approve(context.vault.address, mainAmount);
		await context.col.approve(context.vault.address, colAmount);
		return context.vaultManagerUniswapMainAsset.depositAndBorrow(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const join_Pool = async(main, mainAmount, colAmount, usdpAmount) => {
		await main.approve(context.vault.address, mainAmount);
		await context.col.approve(context.vault.address, colAmount);
		return context.vaultManagerUniswapPoolToken.depositAndBorrow(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // underlying token price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const buyout = (main, user, from = context.deployer) => {
		return context.liquidationAuction.buyout(
			main.address,
			user,
			{ from }
		);
	};

	const triggerLiquidation = (main, user, from = context.deployer) => {
		return context.liquidatorMainAsset.triggerLiquidation(
			main.address,
			user,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
			{ from }
		);
	};

	const triggerLiquidation_Pool = (main, user, from = context.deployer) => {
		return context.liquidatorPoolToken.triggerLiquidation(
			main.address,
			user,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
			{ from }
		);
	};

	const exit = async(main, mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswapMainAsset.withdrawAndRepay(
			main.address,
			mainAmount, // main
			colAmount, // COL
			usdpAmount,	// USDP
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const exit_Pool = async(main, mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswapPoolToken.withdrawAndRepay(
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
		return context.vaultManagerUniswapMainAsset.withdrawAndRepay(
			main.address,
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const withdrawAndRepay_Pool = async(main, mainAmount, colAmount, usdpAmount) => {
		return context.vaultManagerUniswapPoolToken.withdrawAndRepay(
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
		return context.vaultManagerUniswapMainAsset.withdrawAndRepay_Eth(
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const withdrawAndRepayCol = async(main, mainAmount, colAmount, usdpAmount) => {
		await context.col.approve(context.vault.address, MAX_UINT);
		return context.vaultManagerUniswapMainAsset.withdrawAndRepayUsingCol(
			main.address,
			mainAmount,
			colAmount,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // main price proof
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const withdrawAndRepayCol_Pool = async(main, mainAmount, colAmount, usdpAmount) => {
		await context.col.approve(context.vault.address, MAX_UINT);
		return context.vaultManagerUniswapPoolToken.withdrawAndRepayUsingCol(
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
		return context.vaultManagerUniswapMainAsset.repayUsingCol(
			main.address,
			usdpAmount,
			['0x', '0x', '0x', '0x'], // COL price proof
		);
	};

	const repayUsingCol_Pool = async(main, usdpAmount) => {
		await context.col.approve(context.vault.address, MAX_UINT);
		return context.vaultManagerUniswapPoolToken.repayUsingCol(
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

		context.uniswapOracleMainAsset = await UniswapOracleMainAsset.new(
			context.uniswapFactory.address,
			context.weth.address,
			context.chainlinkAggregator.address,
		);

		context.uniswapOraclePoolToken = await UniswapOraclePoolToken.new(
			context.uniswapOracleMainAsset.address
		);

		const parametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.usdp = await USDP.new(parametersAddr);

		const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.vaultParameters = await VaultParameters.new(vaultAddr, context.foundation);
		context.vault = await Vault.new(context.vaultParameters.address, context.col.address, context.usdp.address, context.weth.address);

		context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
		await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);
		context.liquidatorMainAsset = await LiquidatorMainAsset.new(context.vaultManagerParameters.address, context.uniswapOracleMainAsset.address);

		context.liquidatorPoolToken = await LiquidatorPoolToken.new(context.vaultManagerParameters.address, context.uniswapOraclePoolToken.address);


		context.liquidationAuction = await LiquidationAuction01.new(context.vaultManagerParameters.address);

		context.vaultManagerUniswapMainAsset = await VaultManagerUniswapMainAsset.new(
			context.vaultManagerParameters.address,
			context.uniswapOracleMainAsset.address,
		);

		context.vaultManagerStandard = await VaultManagerStandard.new(
			context.vault.address,
		);

		context.vaultManagerUniswapPoolToken = await VaultManagerUniswapPoolToken.new(
			context.vaultManagerParameters.address,
			context.uniswapOraclePoolToken.address,
		);

		context.uniswapRouter = await UniswapV2Router02.new(context.uniswapFactory.address, context.weth.address);

		await context.weth.approve(context.uniswapRouter.address, ether('100'));

		// Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
		await poolDeposit(context.col, 250);

		// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
		await poolDeposit(context.mainCollateral, 125);

		await context.vaultParameters.setVaultAccess(context.vaultManagerUniswapMainAsset.address, true);
		await context.vaultParameters.setVaultAccess(context.vaultManagerUniswapPoolToken.address, true);
		await context.vaultParameters.setVaultAccess(context.liquidatorMainAsset.address, true);
		await context.vaultParameters.setVaultAccess(context.liquidatorPoolToken.address, true);
		await context.vaultParameters.setVaultAccess(context.vaultManagerStandard.address, true);
		await context.vaultParameters.setVaultAccess(context.liquidationAuction.address, true);

		await context.vaultManagerParameters.setCollateral(
			context.mainCollateral.address,
			'0', // stability fee
			'13', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			'0', // liquidation discount (3 decimals)
			'1000', // devaluation period in blocks
			ether('100000'), // debt limit
			[1], // enabled oracles
			3,
			5,
		);

		await context.vaultManagerParameters.setCollateral(
			context.weth.address,
			'0', // stability fee
			'13', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			'0', // liquidation discount (3 decimals)
			'1000', // devaluation period in blocks
			ether('100000'), // debt limit
			[1], // enabled oracles
			3,
			5,
		);

		await context.vaultManagerParameters.setCollateral(
			await context.uniswapFactory.getPair(context.weth.address, context.mainCollateral.address),
			'0', // stability fee
			'13', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			'0', // liquidation discount (3 decimals)
			'1000', // devaluation period in blocks
			ether('100000'), // debt limit
			[2], // enabled oracles
			3,
			5,
		);

		context.poolToken = await getPoolToken(context.mainCollateral.address);
		await context.vaultManagerParameters.setInitialCollateralRatio(context.col.address, 67);
		await context.vaultManagerParameters.setLiquidationRatio(context.col.address, 68);
	};

	return {
		poolDeposit,
		spawn,
		spawn_Pool,
		spawnEth,
		approveCollaterals,
		join,
		join_Pool,
		buyout,
		triggerLiquidation,
		triggerLiquidation_Pool,
		exit,
		exit_Pool,
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
		repayUsingCol_Pool,
		withdrawAndRepayCol_Pool,
		withdrawAndRepay_Pool,
	}
}
