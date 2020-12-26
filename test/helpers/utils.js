const Vault = artifacts.require('Vault');
const VaultParameters = artifacts.require('VaultParameters');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const KeydonixOracleMainAssetMock = artifacts.require('KeydonixOracleMainAsset_Mock');
const KeydonixOraclePoolTokenMock = artifacts.require('KeydonixOraclePoolToken_Mock');
const Keep3rOracleMainAssetMock = artifacts.require('Keep3rOracleMainAsset_Mock');
const Keep3rOraclePoolTokenMock = artifacts.require('Keep3rOraclePoolToken_Mock');
const ChainlinkOracleMainAssetMock = artifacts.require('ChainlinkOracleMainAsset_Mock');
const ChainlinkOraclePoolTokenMock = artifacts.require('ChainlinkOraclePoolToken_Mock');
const ChainlinkAggregator = artifacts.require('ChainlinkAggregator_Mock');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const IUniswapV2Pair = artifacts.require('IUniswapV2PairFull');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManagerStandard = artifacts.require('VaultManagerStandard');
const VaultManagerKeydonixMainAsset = artifacts.require('VaultManagerKeydonixMainAsset');
const VaultManagerKeydonixPoolToken = artifacts.require('VaultManagerKeydonixPoolToken');
const VaultManagerKeep3rMainAsset = artifacts.require('VaultManagerKeep3rMainAsset');
const VaultManagerKeep3rPoolToken = artifacts.require('VaultManagerKeep3rPoolToken');
const VaultManagerChainlinkMainAsset = artifacts.require('VaultManagerChainlinkMainAsset');
const VaultManagerChainlinkPoolToken = artifacts.require('VaultManagerChainlinkPoolToken');
const LiquidatorKeydonixMainAsset = artifacts.require('LiquidationTriggerKeydonixMainAsset');
const LiquidatorKeydonixPoolToken = artifacts.require('LiquidationTriggerKeydonixPoolToken');
const LiquidatorKeep3rMainAsset = artifacts.require('LiquidationTriggerKeep3rMainAsset');
const LiquidatorKeep3rPoolToken = artifacts.require('LiquidationTriggerKeep3rPoolToken');
const LiquidatorChainlinkMainAsset = artifacts.require('LiquidationTriggerChainlinkMainAsset');
const LiquidatorChainlinkPoolToken = artifacts.require('LiquidationTriggerChainlinkPoolToken');
const LiquidationAuction01 = artifacts.require('LiquidationAuction01');
const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode } = require('./deployUtils');
const BN = web3.utils.BN;
const { expect } = require('chai');
const getWrapper = require('./wrappers');

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

module.exports = (context, mode) => {
	const keydonix = mode.startsWith('keydonix');
	const keep3r = mode.startsWith('keep3r');
	const chainlink = mode.startsWith('chainlink');

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

	context.approveCollaterals = async (main, mainAmount, colAmount, from = context.deployer) => {
		await main.approve(context.vault.address, mainAmount, { from });
		return context.col.approve(context.vault.address, colAmount, { from });
	};

	const getPoolToken = async (mainAddress) => {
		const poolAddress = await context.uniswapFactory.getPair(context.weth.address, mainAddress);
		return IUniswapV2Pair.at(poolAddress);
	};

	const repayAllAndWithdraw = async (main, user) => {
		const totalDebt = await context.vault.getTotalDebt(main.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		const mainAmount = await context.vault.collaterals(main.address, user);
		const colAmount = await context.vault.colToken(main.address, user);
		return context.vaultManagerStandard.repayAllAndWithdraw(main.address, mainAmount, colAmount);
	};

	const repayAllAndWithdrawEth = async (user) => {
		const mainAmount = await context.vault.collaterals(context.weth.address, user);
		const colAmount = await context.vault.colToken(context.weth.address, user);
		return context.vaultManagerStandard.repayAllAndWithdraw_Eth(mainAmount, colAmount);
	};

	const repay = async (main, user, usdpAmount) => {
		const totalDebt = await context.vault.getTotalDebt(main.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		return context.vaultManagerStandard.repay(
			main.address,
			usdpAmount,
		);
	}

	const updatePrice = async () => {
		if (keydonix || keep3r) {
			return context.chainlinkAggregator.setPrice(await context.chainlinkAggregator.latestAnswer());
		} else if (chainlink) {
			await context.ethUsd.setPrice(await context.ethUsd.latestAnswer());
			await context.mainUsd.setPrice(await context.mainUsd.latestAnswer());
		}
	}

	const buyout = (main, user, from = context.deployer) => {
		return context.liquidationAuction.buyout(
			main.address,
			user,
			{ from }
		);
	};

	const deploy = async () => {
		context.col = await DummyToken.new("Unit Protocol Token", "COL", 18, ether('1000000'));
		context.weth = await WETH.new();
		context.mainCollateral = await DummyToken.new("STAKE clone", "STAKE", 18, ether('1000000'));

		await context.weth.deposit({ value: ether('0.1') });
		const uniswapFactoryAddr = await deployContractBytecode(UniswapV2FactoryDeployCode, context.deployer, web3);
		context.uniswapFactory = await IUniswapV2Factory.at(uniswapFactoryAddr);

		const parametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.usdp = await USDP.new(parametersAddr);

		const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.vaultParameters = await VaultParameters.new(vaultAddr, context.foundation);
		context.vault = await Vault.new(context.vaultParameters.address, context.col.address, context.usdp.address, context.weth.address);

		let minColPercent, maxColPercent
		let mainAssetOracleType, poolTokenOracleType
		if (keep3r || keydonix) {
			minColPercent = 3
			maxColPercent = 5
			context.chainlinkAggregator = await ChainlinkAggregator.new(250e8, 8);
		} else {
			minColPercent = 0
			maxColPercent = 0
		}

		if (keydonix) {
			mainAssetOracleType = 1
			poolTokenOracleType = 2
			context.keydonixOracleMainAssetMock = await KeydonixOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.chainlinkAggregator.address,
			)
			context.keydonixOraclePoolTokenMock = await KeydonixOraclePoolTokenMock.new(
				context.keydonixOracleMainAssetMock.address
			)
		} else if (keep3r) {
			mainAssetOracleType = 3
			poolTokenOracleType = 4
			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.chainlinkAggregator.address,
			);
			context.keep3rOraclePoolTokenMock = await Keep3rOraclePoolTokenMock.new(
				context.keep3rOracleMainAssetMock.address
			);
		} else if (chainlink) {
			mainAssetOracleType = 5
			poolTokenOracleType = 6
			context.ethUsd = await ChainlinkAggregator.new(250e8, 8);
			context.mainUsd = await ChainlinkAggregator.new(2e8, 8);
			context.mainEth = await ChainlinkAggregator.new(0.008e18, 18); // 1/125 ETH
			context.chainlinkOracleMainAssetMock = await ChainlinkOracleMainAssetMock.new(
				[context.mainCollateral.address, context.weth.address],
				[context.mainUsd.address, context.ethUsd.address],
				[],
				[],
				context.weth.address,
				context.vaultParameters.address
			);
			context.chainlinkOraclePoolTokenMock = await ChainlinkOraclePoolTokenMock.new(
				context.chainlinkOracleMainAssetMock.address
			);
		}

		context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
		await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);
		if (keydonix) {
			context.liquidatorKeydonixMainAsset = await LiquidatorKeydonixMainAsset.new(context.vaultManagerParameters.address, context.keydonixOracleMainAssetMock.address);
			context.liquidatorKeydonixPoolToken = await LiquidatorKeydonixPoolToken.new(context.vaultManagerParameters.address, context.keydonixOraclePoolTokenMock.address);
		} else if (keep3r) {
			context.liquidatorKeep3rMainAsset = await LiquidatorKeep3rMainAsset.new(context.vaultManagerParameters.address, context.keep3rOracleMainAssetMock.address);
			context.liquidatorKeep3rPoolToken = await LiquidatorKeep3rPoolToken.new(context.vaultManagerParameters.address, context.keep3rOraclePoolTokenMock.address);
		} else if (chainlink) {
			context.liquidatorChainlinkMainAsset = await LiquidatorChainlinkMainAsset.new(context.vaultManagerParameters.address, context.chainlinkOracleMainAssetMock.address);
			context.liquidatorChainlinkPoolToken = await LiquidatorChainlinkPoolToken.new(context.vaultManagerParameters.address, context.chainlinkOraclePoolTokenMock.address);
		}

		context.liquidationAuction = await LiquidationAuction01.new(context.vaultManagerParameters.address);

		if (keydonix) {
			context.vaultManagerKeydonixMainAsset = await VaultManagerKeydonixMainAsset.new(
				context.vaultManagerParameters.address,
				context.keydonixOracleMainAssetMock.address,
			);
			context.vaultManagerKeydonixPoolToken = await VaultManagerKeydonixPoolToken.new(
				context.vaultManagerParameters.address,
				context.keydonixOraclePoolTokenMock.address,
			);
		} else if (keep3r) {
			context.vaultManagerKeep3rMainAsset = await VaultManagerKeep3rMainAsset.new(
				context.vaultManagerParameters.address,
				context.keep3rOracleMainAssetMock.address,
			);
			context.vaultManagerKeep3rPoolToken = await VaultManagerKeep3rPoolToken.new(
				context.vaultManagerParameters.address,
				context.keep3rOraclePoolTokenMock.address,
			);
		} else if (chainlink) {
			context.vaultManagerChainlinkMainAsset = await VaultManagerChainlinkMainAsset.new(
				context.vaultManagerParameters.address,
				context.chainlinkOracleMainAssetMock.address,
			);
			context.vaultManagerChainlinkPoolToken = await VaultManagerChainlinkPoolToken.new(
				context.vaultManagerParameters.address,
				context.chainlinkOraclePoolTokenMock.address,
			);
		}

		context.vaultManagerStandard = await VaultManagerStandard.new(
			context.vault.address,
		);

		context.uniswapRouter = await UniswapV2Router02.new(context.uniswapFactory.address, context.weth.address);

		await context.weth.approve(context.uniswapRouter.address, ether('100'));

		// Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
		await poolDeposit(context.col, 250);

		// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
		await poolDeposit(context.mainCollateral, 125);


		// set access of position manipulation contracts to the Vault
		if (keydonix) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonixMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonixPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeydonixMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeydonixPoolToken.address, true);
		} else if (keep3r) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rPoolToken.address, true);
		} else if (chainlink) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerChainlinkMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerChainlinkPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorChainlinkMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorChainlinkPoolToken.address, true);
		}

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
			[mainAssetOracleType], // enabled oracles
			minColPercent,
			maxColPercent,
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
			[mainAssetOracleType], // enabled oracles
			minColPercent,
			maxColPercent,
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
			[poolTokenOracleType], // enabled oracles
			minColPercent,
			maxColPercent,
		);

		context.poolToken = await getPoolToken(context.mainCollateral.address);
		await context.vaultManagerParameters.setInitialCollateralRatio(context.col.address, 67);
		await context.vaultManagerParameters.setLiquidationRatio(context.col.address, 68);
	};

	const w = getWrapper(context, mode);

	return {
		poolDeposit,
		spawn: w.spawn,
		spawnEth: w.spawnEth,
		approveCollaterals: context.approveCollaterals,
		join: w.join,
		buyout,
		triggerLiquidation: w.triggerLiquidation,
		exit: w.exit,
		repayAllAndWithdraw,
		repayAllAndWithdrawEth,
		withdrawAndRepay: w.withdrawAndRepay,
		withdrawAndRepayEth: w.withdrawAndRepayEth,
		withdrawAndRepayCol: w.withdrawAndRepayCol,
		deploy,
		updatePrice,
		repay,
		repayUsingCol: w.repayUsingCol,
		expectRevert,
	}
}
