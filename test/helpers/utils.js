const Vault = artifacts.require('Vault');
const VaultParameters = artifacts.require('VaultParameters');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const CurveRegistryMock = artifacts.require('CurveRegistryMock');
const CurvePool = artifacts.require('CurvePool');
const CurveProviderMock = artifacts.require('CurveProviderMock');
const KeydonixOracleMainAssetMock = artifacts.require('KeydonixOracleMainAsset_Mock');
const KeydonixOraclePoolTokenMock = artifacts.require('KeydonixOraclePoolToken_Mock');
const Keep3rOracleMainAssetMock = artifacts.require('Keep3rOracleMainAsset_Mock');
const CurveLPOracle = artifacts.require('CurveLPOracle');
const OraclePoolTokenMock = artifacts.require('OraclePoolToken_Mock');
const BearingAssetOracle = artifacts.require('BearingAssetOracle');
const WrappedToUnderlyingOracle = artifacts.require('WrappedToUnderlyingOracle');
const OracleRegistry = artifacts.require('OracleRegistry');
const ChainlinkOracleMainAsset = artifacts.require('ChainlinkedOracleMainAsset');
const ChainlinkAggregator = artifacts.require('ChainlinkAggregator_Mock');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const IUniswapV2Pair = artifacts.require('IUniswapV2PairFull');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const CDPManager = artifacts.require('CDPManager01');
const CDPRegistry = artifacts.require('CDPRegistry');
const CollateralRegistry = artifacts.require('CollateralRegistry');

const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode } = require('./deployUtils');
const BN = web3.utils.BN;
const { expect } = require('chai');
const getWrapper = require('./wrappers');

const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

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
	const uniswapKeep3r = mode.startsWith('uniswapKeep3r');
	const sushiswapKeep3r = mode.startsWith('sushiswapKeep3r');
	const chainlink = mode.startsWith('chainlink');
	const bearingAssetSimple = mode.startsWith('bearingAssetSimple');
	const curveLP = mode.startsWith('curveLP');

	const isLP = mode.includes('PoolToken');

	const poolDeposit = async (token, collateralAmount, decimals) => {
		collateralAmount = decimals ? String(collateralAmount * 10 ** decimals) : ether(collateralAmount.toString());
		collateralAmount = new BN(collateralAmount).div(new BN((10 ** 6).toString()));
		const ethAmount = ether('1').div(new BN((10 ** 6)));
		await token.approve(context.uniswapRouter.address, collateralAmount);
		await context.uniswapRouter.addLiquidity(
			token.address,
			context.weth.address,
			collateralAmount,
			ethAmount,
			collateralAmount,
			ethAmount,
			context.deployer,
			1e18.toString(), // deadline
		);
	};

	context.approveCollaterals = async (main, mainAmount, from = context.deployer) => {
		return main.approve(context.vault.address, mainAmount, { from });
	};

	const getPoolToken = async (mainAddress) => {
		const poolAddress = await context.uniswapFactory.getPair(context.weth.address, mainAddress);
		return IUniswapV2Pair.at(poolAddress);
	};

	const repayAllAndWithdraw = async (main, user) => {
		const totalDebt = await context.vault.getTotalDebt(main.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		const mainAmount = await context.vault.collaterals(main.address, user);
		return context.vaultManager.exit(main.address, mainAmount, MAX_UINT);
	};

	const repayAllAndWithdrawEth = async (user) => {
		const totalDebt = await context.vault.getTotalDebt(context.weth.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		const mainAmount = await context.vault.collaterals(context.weth.address, user);
		await context.weth.approve(context.vaultManager.address, mainAmount);
		return context.vaultManager.exit_Eth(mainAmount, MAX_UINT);
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
			await context.ethUsd.setPrice(await context.ethUsd.latestAnswer());
			if (chainlink) {
				await context.mainUsd.setPrice(await context.mainUsd.latestAnswer());
			}
	}

	const buyout = keydonix ? (main, user, from = context.deployer) => {
		return context.liquidationAuction.buyout(
			main.address,
			user,
			{ from }
		);
	} : (main, user, from = context.deployer) => {
		return context.vaultManager.buyout(
			main.address,
			user,
			{ from }
		);
	};

	const deploy = async () => {
		context.weth = await WETH.new();
		context.mainCollateral = await DummyToken.new("STAKE clone", "STAKE", 18, ether('1000000'));

		const uniswapFactoryAddr = await deployContractBytecode(UniswapV2FactoryDeployCode, context.deployer, web3);
		context.uniswapFactory = await IUniswapV2Factory.at(uniswapFactoryAddr);

		context.uniswapRouter = await UniswapV2Router02.new(context.uniswapFactory.address, context.weth.address);

		await context.weth.deposit({ value: ether('0.1') });
		await context.weth.approve(context.uniswapRouter.address, ether('100'));

		// Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
		await poolDeposit(context.mainCollateral, 125);

		if (isLP) {
			context.poolToken = await getPoolToken(context.mainCollateral.address);
		}

		const parametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.usdp = await USDP.new(parametersAddr);

		const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.vaultParameters = await VaultParameters.new(vaultAddr, context.foundation);
		context.vault = await Vault.new(context.vaultParameters.address, '0x0000000000000000000000000000000000000000', context.usdp.address, context.weth.address);

		let minColPercent, maxColPercent
		let mainAssetOracleType, poolTokenOracleType
		if (keydonix) {
			minColPercent = 3
			maxColPercent = 5
		} else {
			minColPercent = 0
			maxColPercent = 0
		}

		context.ethUsd = await ChainlinkAggregator.new(250e8, 8);
		context.mainUsd = await ChainlinkAggregator.new(2e8, 8);
		context.mainEth = await ChainlinkAggregator.new(0.008e18, 18); // 1/125 ETH
		context.chainlinkOracleMainAsset = await ChainlinkOracleMainAsset.new(
			[context.mainCollateral.address, context.weth.address],
			[context.mainUsd.address, context.ethUsd.address],
			[],
			[],
			context.weth.address,
			context.vaultParameters.address
		);

		// curveLockedAsset - is underlying token
		// mainCollateral is LP is this case
		context.curveLockedAsset = await DummyToken.new("USDC", "USDC", 18, ether('1000000'));
		context.curvePool = await CurvePool.new()
		await context.curvePool.setPool(ether('1'), [context.curveLockedAsset.address])
		context.curveRegistry = await CurveRegistryMock.new(context.mainCollateral.address, context.curvePool.address, 1)
		context.curveProvider = await CurveProviderMock.new(context.curveRegistry.address)
		context.oracleRegistry = await OracleRegistry.new(context.vaultParameters.address, context.weth.address)

		await context.oracleRegistry.setOracle(5, context.chainlinkOracleMainAsset.address, true);
		await context.oracleRegistry.setOracleTypeToAsset(context.weth.address, 5);

		context.wrappedToUnderlyingOracle = await WrappedToUnderlyingOracle.new(
			context.vaultParameters.address,
			context.oracleRegistry.address,
		)

		if (isLP) {
			context.oraclePoolToken = await OraclePoolTokenMock.new(
				context.oracleRegistry.address,
				context.weth.address,
			);
		}

		if (keydonix) {
			mainAssetOracleType = 1
			poolTokenOracleType = 2
			context.keydonixOracleMainAssetMock = await KeydonixOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)
			context.keydonixOraclePoolTokenMock = await KeydonixOraclePoolTokenMock.new(
				context.keydonixOracleMainAssetMock.address
			)
		} else if (uniswapKeep3r || sushiswapKeep3r) {
			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			);
			if (uniswapKeep3r) {
				mainAssetOracleType = 3
				context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address, true)
				context.oracleRegistry.setOracleTypeToAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 4
					context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address, false)
					context.oracleRegistry.setOracleTypeToAsset(context.poolToken.address, poolTokenOracleType)
				}
			} else if (sushiswapKeep3r) {
				mainAssetOracleType = 7
				context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address, true)
				context.oracleRegistry.setOracleTypeToAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 8
					context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address, false)
					context.oracleRegistry.setOracleTypeToAsset(context.poolToken.address, poolTokenOracleType)
				}
			}
		} else if (chainlink) {
			mainAssetOracleType = 5
			poolTokenOracleType = 6

			context.oracleRegistry.setOracleTypeToAsset(context.mainCollateral.address, mainAssetOracleType)

			if (isLP) {
				poolTokenOracleType = 6
				context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address, false)
				context.oracleRegistry.setOracleTypeToAsset(context.poolToken.address, poolTokenOracleType)
			}

		} else if (bearingAssetSimple) {
			mainAssetOracleType = 9

			context.bearingAsset = await DummyToken.new("Bearing Asset", "BeA", 18, ether('1000'));

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address, true)
			context.oracleRegistry.setOracleTypeToAsset(context.mainCollateral.address, 7)

			context.bearingAssetOracle = await BearingAssetOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			await context.bearingAssetOracle.setUnderlying(context.bearingAsset.address, context.mainCollateral.address)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.bearingAssetOracle.address, true)
			context.oracleRegistry.setOracleTypeToAsset(context.bearingAsset.address, 9)


		} else if (curveLP) {
			context.curveLockedAssetUsdPrice = await ChainlinkAggregator.new(1e8.toString(), 8);
			await context.chainlinkOracleMainAsset.setAggregators(
				[context.curveLockedAsset.address],
				[context.curveLockedAssetUsdPrice.address],
				[],
				[]
			);

			mainAssetOracleType = 11

			context.curveLpOracle = await CurveLPOracle.new(context.curveProvider.address, context.oracleRegistry.address)

			context.oracleRegistry.setOracleTypeToAsset(context.curveLockedAsset.address, 5)

			context.oracleRegistry.setOracle(10, context.curveLpOracle.address, true)
			context.oracleRegistry.setOracleTypeToAsset(context.mainCollateral.address, 10)

			context.wrappedAsset = await DummyToken.new("Wrapper Curve LP", "WCLP", 18, ether('100000000000'))

			await context.wrappedToUnderlyingOracle.setUnderlying(context.wrappedAsset.address, context.mainCollateral.address)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.wrappedToUnderlyingOracle.address, true)
			context.oracleRegistry.setOracleTypeToAsset(context.wrappedAsset.address, mainAssetOracleType)

		}

		context.collateralRegistry = await CollateralRegistry.new(context.vaultParameters.address, [context.mainCollateral.address]);
		context.cdpRegistry = await CDPRegistry.new(context.vault.address, context.collateralRegistry.address);
		context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
		await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);

		if (keydonix) {
			context.liquidatorKeydonixMainAsset = await LiquidatorKeydonixMainAsset.new(context.vaultManagerParameters.address, context.keydonixOracleMainAssetMock.address);
			context.liquidatorKeydonixPoolToken = await LiquidatorKeydonixPoolToken.new(context.vaultManagerParameters.address, context.keydonixOraclePoolTokenMock.address);

			context.liquidationAuction = await LiquidationAuction02.new(
				context.vaultManagerParameters.address,
				context.curveProvider.address,
				context.wrappedToUnderlyingOracle.address
			);
		} else {
			context.vaultManager = await CDPManager.new(context.vaultManagerParameters.address, context.oracleRegistry.address, context.curveProvider.address, context.cdpRegistry.address);
		}

		if (keydonix) {
			context.vaultManagerKeydonixMainAsset = await VaultManagerKeydonixMainAsset.new(
				context.vaultManagerParameters.address,
				context.keydonixOracleMainAssetMock.address,
			);
			context.vaultManagerKeydonixPoolToken = await VaultManagerKeydonixPoolToken.new(
				context.vaultManagerParameters.address,
				context.keydonixOraclePoolTokenMock.address,
			);
			context.vaultManagerStandard = await VaultManagerStandard.new(
				context.vault.address,
			);
		}


		// set access of position manipulation contracts to the Vault
		if (keydonix) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonixMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonixPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeydonixMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeydonixPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidationAuction.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerStandard.address, true);
		} else {
			await context.vaultParameters.setVaultAccess(context.vaultManager.address, true);
		}

		await context.vaultManagerParameters.setCollateral(
			bearingAssetSimple ? context.bearingAsset.address : curveLP ? context.wrappedAsset.address : context.mainCollateral.address,
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

		if (keydonix || uniswapKeep3r || sushiswapKeep3r || chainlink) {
			await context.vaultManagerParameters.setCollateral(
				context.weth.address,
				'0', // stability fee
				'13', // liquidation fee
				'67', // initial collateralization
				'68', // liquidation ratio
				'0', // liquidation discount (3 decimals)
				'1000', // devaluation period in blocks
				ether('100000'), // debt limit
				[5], // enabled oracles
				minColPercent,
				maxColPercent,
			);
		}

		if (poolTokenOracleType) {
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
		}
	};

	const w = getWrapper(context, mode);

	return {
		poolDeposit,
		spawn: w.join,
		spawnEth: w.joinEth,
		approveCollaterals: context.approveCollaterals,
		join: w.join,
		joinEth: w.joinEth,
		buyout,
		triggerLiquidation: w.triggerLiquidation,
		exit: w.exit,
		exitEth: w.exitEth,
		repayAllAndWithdraw,
		repayAllAndWithdrawEth,
		withdrawAndRepay: w.exit,
		withdrawAndRepayEth: w.exitEth,
		deploy,
		updatePrice,
		repay,
		expectRevert,
	}
}
