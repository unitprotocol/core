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
const Keep3rOraclePoolTokenMock = artifacts.require('Keep3rOraclePoolToken_Mock');
const BearingAssetOracleSimple = artifacts.require('BearingAssetOracleSimple');
const WrappedToUnderlyingOracle = artifacts.require('WrappedToUnderlyingOracle');
const OracleRegistry = artifacts.require('OracleRegistry');
const ChainlinkOracleMainAssetMock = artifacts.require('ChainlinkOracleMainAsset_Mock');
const ChainlinkAggregator = artifacts.require('ChainlinkAggregator_Mock');
const UniswapV2FactoryDeployCode = require('./UniswapV2DeployCode');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const IUniswapV2Pair = artifacts.require('IUniswapV2PairFull');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManagerStandard = artifacts.require('VaultManagerStandard');
const VaultManagerKeydonixMainAsset = artifacts.require('VaultManagerKeydonixMainAsset');
const VaultManagerKeydonixPoolToken = artifacts.require('VaultManagerKeydonixPoolToken');
const VaultManagerKeep3rUniswapMainAsset = artifacts.require('VaultManagerKeep3rUniswapMainAsset');
const vaultManagerKeep3rUniswapPoolToken = artifacts.require('VaultManagerKeep3rUniswapPoolToken');
const VaultManagerKeep3rSushiSwapMainAsset = artifacts.require('VaultManagerKeep3rSushiSwapMainAsset');
const VaultManagerKeep3rSushiSwapPoolToken = artifacts.require('VaultManagerKeep3rSushiSwapPoolToken');
const VaultManagerChainlinkMainAsset = artifacts.require('VaultManagerChainlinkMainAsset');
const VaultManagerSimple = artifacts.require('VaultManagerSimple');
const LiquidatorKeydonixMainAsset = artifacts.require('LiquidationTriggerKeydonixMainAsset');
const LiquidatorKeydonixPoolToken = artifacts.require('LiquidationTriggerKeydonixPoolToken');
const LiquidatorKeep3rMainAsset = artifacts.require('LiquidationTriggerKeep3rMainAsset');
const LiquidatorKeep3rPoolToken = artifacts.require('LiquidationTriggerKeep3rPoolToken');
const LiquidatorKeep3rSushiSwapMainAsset = artifacts.require('LiquidationTriggerKeep3rSushiSwapMainAsset');
const LiquidatorKeep3rSushiSwapPoolToken = artifacts.require('LiquidationTriggerKeep3rSushiSwapPoolToken');
const LiquidatorChainlinkMainAsset = artifacts.require('LiquidationTriggerChainlinkMainAsset');
const LiquidationTriggerSimple = artifacts.require('LiquidationTriggerSimple');
const LiquidationAuction02 = artifacts.require('LiquidationAuction02');
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
	const uniswapKeep3r = mode.startsWith('uniswapKeep3r');
	const sushiswapKeep3r = mode.startsWith('sushiswapKeep3r');
	const chainlink = mode.startsWith('chainlink');
	const bearingAssetSimple = mode.startsWith('bearingAssetSimple');
	const curveLP = mode.startsWith('curveLP');

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
		return context.vaultManagerStandard.repayAllAndWithdraw(main.address, mainAmount);
	};

	const repayAllAndWithdrawEth = async (user) => {
		const mainAmount = await context.vault.collaterals(context.weth.address, user);
		return context.vaultManagerStandard.repayAllAndWithdraw_Eth(mainAmount);
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
		if (keydonix || uniswapKeep3r || sushiswapKeep3r) {
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
		if (uniswapKeep3r || keydonix) {
			minColPercent = 3
			maxColPercent = 5
			context.chainlinkAggregator = await ChainlinkAggregator.new(250e8, 8);
		} else {
			if (sushiswapKeep3r || bearingAssetSimple) {
				context.chainlinkAggregator = await ChainlinkAggregator.new(250e8, 8);
			}
			minColPercent = 0
			maxColPercent = 0
		}

		context.curveLockedAsset = await DummyToken.new("USDC", "USDC", 18, ether('1000000'));
		context.curvePool = await CurvePool.new()
		await context.curvePool.setPool(ether('1'), [context.curveLockedAsset.address])
		context.curveRegistry = await CurveRegistryMock.new(context.mainCollateral.address, context.curvePool.address, 1)
		context.curveProvider = await CurveProviderMock.new(context.curveRegistry.address)
		context.oracleRegistry = await OracleRegistry.new(context.vaultParameters.address)

		context.wrappedToUnderlyingOracle = await WrappedToUnderlyingOracle.new(
			context.vaultParameters.address,
			context.oracleRegistry.address,
		)

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
		} else if (uniswapKeep3r || sushiswapKeep3r) {
			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.chainlinkAggregator.address,
			);
			context.keep3rOraclePoolTokenMock = await Keep3rOraclePoolTokenMock.new(
				context.keep3rOracleMainAssetMock.address
			);
			if (uniswapKeep3r) {
				mainAssetOracleType = 3
				poolTokenOracleType = 4
			} else if (sushiswapKeep3r) {
				mainAssetOracleType = 7
				poolTokenOracleType = 8
			}
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
		} else if (bearingAssetSimple) {
			mainAssetOracleType = 9

			context.bearingAsset = await DummyToken.new("Bearing Asset", "BeA", 18, ether('1000'));

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.chainlinkAggregator.address,
			)

			context.oracleRegistry = await OracleRegistry.new(context.vaultParameters.address)

			context.oracleRegistry.setOracle(
				context.mainCollateral.address,
				context.keep3rOracleMainAssetMock.address,
				7
			)

			context.bearingAssetOracle = await BearingAssetOracleSimple.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			await context.bearingAssetOracle.setUnderlying(context.bearingAsset.address, context.mainCollateral.address)

		} else if (curveLP) {
			context.ethUsd = await ChainlinkAggregator.new(100e8, 8);
			context.curveLockedAssetEthPrice = await ChainlinkAggregator.new(0.01e18.toString(), 18); // 1/125 ETH
			context.chainlinkOracleMainAssetMock = await ChainlinkOracleMainAssetMock.new(
				[context.weth.address],
				[context.ethUsd.address],
				[context.curveLockedAsset.address],
				[context.curveLockedAssetEthPrice.address],
				context.weth.address,
				context.vaultParameters.address
			);

			mainAssetOracleType = 11

			context.curveLpOracle = await CurveLPOracle.new(context.curveProvider.address, context.chainlinkOracleMainAssetMock.address)

			context.oracleRegistry.setOracle(
				context.mainCollateral.address,
				context.curveLpOracle.address,
				10
			)

			context.wrappedAsset = await DummyToken.new("Wrapper Curve LP", "WCLP", 18, ether('100000000000'))

			await context.wrappedToUnderlyingOracle.setUnderlying(context.wrappedAsset.address, context.mainCollateral.address)

		}

		context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
		await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);

		if (keydonix) {
			context.liquidatorKeydonixMainAsset = await LiquidatorKeydonixMainAsset.new(context.vaultManagerParameters.address, context.keydonixOracleMainAssetMock.address);
			context.liquidatorKeydonixPoolToken = await LiquidatorKeydonixPoolToken.new(context.vaultManagerParameters.address, context.keydonixOraclePoolTokenMock.address);
		} else if (uniswapKeep3r) {
			context.liquidatorKeep3rMainAsset = await LiquidatorKeep3rMainAsset.new(context.vaultManagerParameters.address, context.keep3rOracleMainAssetMock.address);
			context.liquidatorKeep3rPoolToken = await LiquidatorKeep3rPoolToken.new(context.vaultManagerParameters.address, context.keep3rOraclePoolTokenMock.address);
		} else if (sushiswapKeep3r) {
			context.liquidatorKeep3rSushiSwapMainAsset = await LiquidatorKeep3rSushiSwapMainAsset.new(context.vaultManagerParameters.address, context.keep3rOracleMainAssetMock.address);
			context.liquidatorKeep3rSushiSwapPoolToken = await LiquidatorKeep3rSushiSwapPoolToken.new(context.vaultManagerParameters.address, context.keep3rOraclePoolTokenMock.address);
		} else if (chainlink) {
			context.liquidatorChainlinkMainAsset = await LiquidatorChainlinkMainAsset.new(context.vaultManagerParameters.address, context.chainlinkOracleMainAssetMock.address);
		} else if (bearingAssetSimple) {
			context.liquidatorSimple = await LiquidationTriggerSimple.new(context.vaultManagerParameters.address, context.bearingAssetOracle.address, mainAssetOracleType);
		} else if (curveLP) {
			context.liquidatorSimple = await LiquidationTriggerSimple.new(context.vaultManagerParameters.address, context.wrappedToUnderlyingOracle.address, mainAssetOracleType);
		}

		context.liquidationAuction = await LiquidationAuction02.new(
			context.vaultManagerParameters.address,
			context.curveProvider.address,
			context.wrappedToUnderlyingOracle.address
		);

		if (keydonix) {
			context.vaultManagerKeydonixMainAsset = await VaultManagerKeydonixMainAsset.new(
				context.vaultManagerParameters.address,
				context.keydonixOracleMainAssetMock.address,
			);
			context.vaultManagerKeydonixPoolToken = await VaultManagerKeydonixPoolToken.new(
				context.vaultManagerParameters.address,
				context.keydonixOraclePoolTokenMock.address,
			);
		} else if (uniswapKeep3r) {
			context.vaultManagerKeep3rUniswapMainAsset = await VaultManagerKeep3rUniswapMainAsset.new(
				context.vaultManagerParameters.address,
				context.keep3rOracleMainAssetMock.address,
			);
			context.vaultManagerKeep3rUniswapPoolToken = await vaultManagerKeep3rUniswapPoolToken.new(
				context.vaultManagerParameters.address,
				context.keep3rOraclePoolTokenMock.address,
			);
		} else if (sushiswapKeep3r) {
			context.vaultManagerKeep3rSushiSwapMainAsset = await VaultManagerKeep3rSushiSwapMainAsset.new(
				context.vaultManagerParameters.address,
				context.keep3rOracleMainAssetMock.address,
			);
			context.vaultManagerKeep3rSushiSwapPoolToken = await VaultManagerKeep3rSushiSwapPoolToken.new(
				context.vaultManagerParameters.address,
				context.keep3rOraclePoolTokenMock.address,
			);
		} else if (chainlink) {
			context.vaultManagerChainlinkMainAsset = await VaultManagerChainlinkMainAsset.new(
				context.vaultManagerParameters.address,
				context.chainlinkOracleMainAssetMock.address,
			);
		} else if (bearingAssetSimple) {
			context.vaultManagerSimple = await VaultManagerSimple.new(
				context.vaultManagerParameters.address,
				context.bearingAssetOracle.address,
				mainAssetOracleType
			);
		} else if (curveLP) {
			context.vaultManagerSimple = await VaultManagerSimple.new(
				context.vaultManagerParameters.address,
				context.wrappedToUnderlyingOracle.address,
				mainAssetOracleType
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
		} else if (uniswapKeep3r) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rUniswapMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rUniswapPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rPoolToken.address, true);
		} else if (sushiswapKeep3r) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rSushiSwapMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeep3rSushiSwapPoolToken.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rSushiSwapMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorKeep3rSushiSwapPoolToken.address, true);
		} else if (chainlink) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerChainlinkMainAsset.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorChainlinkMainAsset.address, true);
		} else if (bearingAssetSimple || curveLP) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerSimple.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidatorSimple.address, true);
		}

		await context.vaultParameters.setVaultAccess(context.vaultManagerStandard.address, true);
		await context.vaultParameters.setVaultAccess(context.liquidationAuction.address, true);

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
				[mainAssetOracleType], // enabled oracles
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
			context.poolToken = await getPoolToken(context.mainCollateral.address);
		}

		if (keydonix || uniswapKeep3r) {
			await context.vaultManagerParameters.setInitialCollateralRatio(context.col.address, 67);
			await context.vaultManagerParameters.setLiquidationRatio(context.col.address, 68);
		}
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
