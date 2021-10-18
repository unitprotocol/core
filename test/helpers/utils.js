const Vault = artifacts.require('Vault');
const VaultParameters = artifacts.require('VaultParameters');
const FoundationMock = artifacts.require('FoundationMock');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const CyWETH = artifacts.require('CyWETH');
const YvWETH = artifacts.require('YvWETH');
const WstETH = artifacts.require('WstETH');
const UnitProxy = artifacts.require('UnitProxy');
const StETH = artifacts.require('StETH');
const CurveRegistryMock = artifacts.require('CurveRegistryMock');
const CurvePool = artifacts.require('CurvePool');
const CurveProviderMock = artifacts.require('CurveProviderMock');
const KeydonixOracleMainAssetMock = artifacts.require('KeydonixOracleMainAsset_Mock');
const KeydonixOraclePoolTokenMock = artifacts.require('KeydonixOraclePoolToken_Mock');
const Keep3rOracleMainAssetMock = artifacts.require('Keep3rOracleMainAsset_Mock');
const CurveLPOracle = artifacts.require('CurveLPOracle');
const OraclePoolToken = artifacts.require('OraclePoolToken');
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
const CDPManagerFallback = artifacts.require('CDPManager01_Fallback');
const LiquidationAuction = artifacts.require('LiquidationAuction02');
const CDPRegistry = artifacts.require('CDPRegistry');
const ForceTransferAssetStore = artifacts.require('ForceTransferAssetStore');
const CollateralRegistry = artifacts.require('CollateralRegistry');
const CyTokenOracle = artifacts.require('CyTokenOracle');
const YvTokenOracle = artifacts.require('YvTokenOracle');
const WstEthOracle = artifacts.require('WstEthOracle');
const StETHPriceFeed = artifacts.require('StETHPriceFeed');
const StETHStableSwapOracle = artifacts.require('StETHStableSwapOracle');
const StETHCurvePool = artifacts.require('StETHCurvePool');

const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode, runDeployment } = require('./deployUtils');
const { createDeployment } = require('../../lib/deployments/core');
const BN = web3.utils.BN;
const { expect } = require('chai');
const getWrapper = require('./wrappers');

const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

let _hre;
const _loadHRE = async function() {
	if (_hre === undefined) {
		process.env.HARDHAT_NETWORK = 'localhost';
		_hre = require("hardhat");

		await _hre.run("compile");
	}

	return _hre;
}


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
	const cyWETHsample = mode.startsWith('cyWETHsample');
	const yvWETHsample = mode.startsWith('yvWETHsample');
	const wstETHsample = mode.startsWith('wstETHsample');


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
		return context.vaultManager.repayAll(main.address, true);
	};

	const repayAllAndWithdrawEth = async (user) => {
		const totalDebt = await context.vault.getTotalDebt(context.weth.address, user);
		await context.usdp.approve(context.vault.address, totalDebt);
		const mainAmount = await context.vault.collaterals(context.weth.address, user);
		await context.weth.approve(context.vaultManager.address, mainAmount);
		return context.vaultManager.exit_Eth(mainAmount, MAX_UINT);
	};

	const repay = async (main, usdpAmount) => {
		await context.usdp.approve(context.vault.address, usdpAmount);
		return context.vaultManagerKeydonix.exit(
			main.address,
			0,
			usdpAmount,
      ['0x', '0x', '0x', '0x'], // main price proof
		);
	}

	const updatePrice = async () => {
			await context.ethUsd.setPrice(await context.ethUsd.latestAnswer());
			if (chainlink) {
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
		context.weth = await WETH.new();
    context.foundation = await FoundationMock.new();
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

		const useDeployment = process.env.USE_DEPLOYMENT && !keydonix;
		if (useDeployment) {
		    const deployment = await createDeployment({
				deployer: context.deployer,
				foundation: context.foundation.address,
				manager: context.deployer,
				wtoken: context.weth.address
			});
			const hre = await _loadHRE();
			const deployed = await runDeployment(deployment, {hre, deployer: context.deployer});
			context.deployed = deployed;

			context.usdp = await USDP.at(deployed.USDP);
			context.vaultParameters = await VaultParameters.at(deployed.VaultParameters);
			context.vault = await Vault.at(deployed.Vault);
			context.oracleRegistry = await OracleRegistry.at(deployed.OracleRegistry);
			context.forceTransferAssetStore = await ForceTransferAssetStore.at(deployed.ForceTransferAssetStore);
			context.chainlinkOracleMainAsset = await ChainlinkOracleMainAsset.at(deployed.ChainlinkedOracleMainAsset);
		}
		else {
		const vaultParametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
		context.usdp = await USDP.new(vaultParametersAddr);

    const vaultProxyAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 2);
		context.vaultParameters = await VaultParameters.new(vaultProxyAddr, context.foundation.address);

    Vault.class_defaults.from = context.deployer;
    context.vaultImplementation = await Vault.new(context.vaultParameters.address, context.usdp.address, context.weth.address);
    // prevent calls to proxy by deployer
    Vault.class_defaults.from = '0x0000000000000000000000000000000000000000';

    await UnitProxy.new(context.vaultImplementation.address, context.deployer, '0x');
    context.vault = await Vault.at(vaultProxyAddr)
    await context.usdp.setMinter(context.vault.address, true);

			context.oracleRegistry = await OracleRegistry.new(context.vaultParameters.address, context.weth.address)

			context.forceTransferAssetStore = await ForceTransferAssetStore.new(context.vaultParameters.address, []);
		}

		let mainAssetOracleType, poolTokenOracleType

		context.ethUsd = await ChainlinkAggregator.new(250e8, 8);
		context.mainUsd = await ChainlinkAggregator.new(2e8, 8);
		context.mainEth = await ChainlinkAggregator.new(0.008e18, 18); // 1/125 ETH
		if (useDeployment) {
			await context.chainlinkOracleMainAsset.setAggregators(
				[context.mainCollateral.address, context.weth.address],
				[context.mainUsd.address, context.ethUsd.address],
				[],
				[]
			);
		}
		else {
			context.chainlinkOracleMainAsset = await ChainlinkOracleMainAsset.new(
				[context.mainCollateral.address, context.weth.address],
				[context.mainUsd.address, context.ethUsd.address],
				[],
				[],
				context.weth.address,
				context.vaultParameters.address
			);
		}
		await context.oracleRegistry.setOracle(5, context.chainlinkOracleMainAsset.address);
		await context.oracleRegistry.setOracleTypeForAsset(context.weth.address, 5);

		if (useDeployment) {
			context.wrappedToUnderlyingOracle = await WrappedToUnderlyingOracle.at(context.deployed.WrappedToUnderlyingOracle);
		} else {
			context.wrappedToUnderlyingOracle = await WrappedToUnderlyingOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)
		}

		if (isLP) {
			context.oraclePoolToken = await OraclePoolToken.new(context.oracleRegistry.address);
		}

		if (keydonix) {
			mainAssetOracleType = 1
			poolTokenOracleType = 2
      const oracleTypes = [mainAssetOracleType]
			context.keydonixOracleMainAssetMock = await KeydonixOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)
      context.oracleRegistry.setOracle(mainAssetOracleType, context.keydonixOracleMainAssetMock.address)
      if (isLP) {
        context.keydonixOraclePoolTokenMock = await KeydonixOraclePoolTokenMock.new(
          context.keydonixOracleMainAssetMock.address
        )
        context.oracleRegistry.setOracle(poolTokenOracleType, context.keydonixOraclePoolTokenMock.address)
        oracleTypes.push(poolTokenOracleType)
      }
      context.oracleRegistry.setKeydonixOracleTypes(oracleTypes)
		} else if (uniswapKeep3r || sushiswapKeep3r) {
			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			);
			if (uniswapKeep3r) {
				mainAssetOracleType = 3
				context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address)
				context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 4
					context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
					context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
				}
			} else if (sushiswapKeep3r) {
				mainAssetOracleType = 7
				context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address)
				context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 8
					context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
					context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
				}
			}
		} else if (chainlink) {
			mainAssetOracleType = 5
			poolTokenOracleType = 6

			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

			if (isLP) {
				poolTokenOracleType = 6
				context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
				context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
			}

		} else if (bearingAssetSimple) {
			mainAssetOracleType = 9

			context.bearingAsset = await DummyToken.new("Bearing Asset", "BeA", 18, ether('1000'));

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.bearingAssetOracle = await BearingAssetOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			await context.bearingAssetOracle.setUnderlying(context.bearingAsset.address, context.mainCollateral.address)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.bearingAssetOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.bearingAsset.address, 9)


		} else if (curveLP) {

			// curveLockedAssets is underlying tokens
			// `mainCollateral` is LP is this case
			// `wrappedAsset` is the collateral
			context.curveLockedAsset1 = await DummyToken.new("USDC", "USDC", 6, 1000000e6);
			context.curveLockedAsset2 = await DummyToken.new("USDT", "USDT", 6, 1000000e6);
			context.curveLockedAsset3 = await DummyToken.new("DAI", "DAI", 18, ether('1000000'));
			context.curvePool = await CurvePool.new()
			await context.curvePool.setPool(ether('1'), [context.curveLockedAsset1.address, context.curveLockedAsset2.address, context.curveLockedAsset3.address])
			context.curveRegistry = await CurveRegistryMock.new(context.mainCollateral.address, context.curvePool.address, 3)
			context.curveProvider = await CurveProviderMock.new(context.curveRegistry.address)

			context.curveLockedAssetUsdPrice = await ChainlinkAggregator.new(1e8.toString(), 8);
			await context.chainlinkOracleMainAsset.setAggregators(
				[context.curveLockedAsset1.address, context.curveLockedAsset2.address, context.curveLockedAsset3.address],
				[context.curveLockedAssetUsdPrice.address, context.curveLockedAssetUsdPrice.address, context.curveLockedAssetUsdPrice.address],
				[],
				[]
			);

			mainAssetOracleType = 11

			context.curveLpOracle = await CurveLPOracle.new(context.curveProvider.address, context.oracleRegistry.address)

			context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset1.address, 5)
			context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset2.address, 5)
			context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset3.address, 5)

			context.oracleRegistry.setOracle(10, context.curveLpOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 10)

			context.wrappedAsset = await DummyToken.new("Wrapper Curve LP", "WCLP", 18, ether('100000000000'))

			await context.forceTransferAssetStore.add(context.wrappedAsset.address);

			await context.wrappedToUnderlyingOracle.setUnderlying(context.wrappedAsset.address, context.mainCollateral.address)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.wrappedToUnderlyingOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.wrappedAsset.address, mainAssetOracleType)

		} else if (cyWETHsample) {
			mainAssetOracleType = 14
      let totalSupply = new BN('1000000000000000000000000');
      let cyTokenImplementation = '0x1A9e503562CE800Ea8e68E2cf0cfA0AEC2eDb509';
			let sampleRate = new BN('100000000000000000000000000');
			context.cyWETH = await CyWETH.new(totalSupply,context.weth.address,cyTokenImplementation,sampleRate);

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.CyTokenOracle = await CyTokenOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
				[cyTokenImplementation],
			)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.CyTokenOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.CyTokenOracle.address, 14)

		} else if (yvWETHsample) {
			mainAssetOracleType = 15
      let totalSupply = new BN('10000000000000000000000');
			let pricePerShare = new BN('1015000000000000000');
			context.yvWETH = await YvWETH.new(totalSupply, context.weth.address, pricePerShare);

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.YvTokenOracle = await YvTokenOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.YvTokenOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.YvTokenOracle.address, 15)

		} else if (wstETHsample) {
			mainAssetOracleType = 16;

			// StETH
			let totalPooledEther = new BN('1000000000000000000000000');
			let totalShares = new BN('2000000000000000000000000');
			context.stETH = await StETH.new(totalPooledEther, totalShares);

			// StETHCurvePool
			let priceCurvePool = new BN('900000000000000000');
			context.stETHCurvePool = await StETHCurvePool.new(priceCurvePool);

			// StableSwapStateOracle
			let priceStableSwapStateOracle = new BN('880000000000000000');
			context.stETHStableSwapOracle = await StETHStableSwapOracle.new(priceStableSwapStateOracle);

			// StETHPriceFeed
			context.stETHPriceFeed = await StETHPriceFeed.new(context.stETHCurvePool.address, context.stETHStableSwapOracle.address);

			// WstETH
			let totalSupplyWstEth = new BN('3000000000000000000000000');
			context.wstETH = await WstETH.new(totalSupplyWstEth, context.stETH.address);

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

      // let stEthDecimals = 18;
			context.WstEthOracle = await WstEthOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
				context.wstETH.address,
				context.stETHPriceFeed.address,
			)

			context.oracleRegistry.setOracle(mainAssetOracleType, context.WstEthOracle.address)
			context.oracleRegistry.setOracleTypeForAsset(context.WstEthOracle.address, 16)

		}

		if (useDeployment) {
			context.collateralRegistry = await CollateralRegistry.at(context.deployed.CollateralRegistry);
			context.cdpRegistry = await CDPRegistry.at(context.deployed.CDPRegistry);
			context.vaultManagerParameters = await VaultManagerParameters.at(context.deployed.VaultManagerParameters);
		}
		else {
			context.collateralRegistry = await CollateralRegistry.new(context.vaultParameters.address, [context.mainCollateral.address]);
			context.cdpRegistry = await CDPRegistry.new(context.vault.address, context.collateralRegistry.address);
			context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
			await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);
		}

		if (keydonix) {
			context.liquidatorKeydonixMainAsset = await LiquidatorKeydonixMainAsset.new(context.vaultManagerParameters.address, context.keydonixOracleMainAssetMock.address);
			context.liquidatorKeydonixPoolToken = await LiquidatorKeydonixPoolToken.new(context.vaultManagerParameters.address, context.keydonixOraclePoolTokenMock.address);
		} else {
			if (useDeployment) {
				context.vaultManager = await CDPManager.at(context.deployed.CDPManager01);
			} else {
				context.vaultManager = await CDPManager.new(context.vaultManagerParameters.address, context.oracleRegistry.address, context.cdpRegistry.address);
			}
		}


		if (useDeployment) {
			context.liquidationAuction = await LiquidationAuction.at(context.deployed.LiquidationAuction02);
		} else {
			context.liquidationAuction = await LiquidationAuction.new(
				context.vaultManagerParameters.address,
				context.cdpRegistry.address,
				context.forceTransferAssetStore.address
			);
		}

		if (keydonix) {
      context.vaultManagerKeydonix = await CDPManagerFallback.new(
        context.vaultManagerParameters.address,
        context.oracleRegistry.address,
        context.cdpRegistry.address
      );
    }
    context.vaultManager = await CDPManager.new(context.vaultManagerParameters.address, context.oracleRegistry.address, context.cdpRegistry.address);


		if (keydonix) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonix.address, true);
		}

		if (!useDeployment) {
    await context.vaultParameters.setVaultAccess(context.vaultManager.address, true);
		await context.vaultParameters.setVaultAccess(context.liquidationAuction.address, true);
		}

		await context.vaultManagerParameters.setCollateral(
			wstETHsample ? context.wstETH.address : yvWETHsample ? context.yvWETH.address : cyWETHsample ? context.cyWETH.address : bearingAssetSimple ? context.bearingAsset.address : curveLP ? context.wrappedAsset.address : context.mainCollateral.address,
			'0', // stability fee
			'13', // liquidation fee
			'67', // initial collateralization
			'68', // liquidation ratio
			'0', // liquidation discount (3 decimals)
			'1000', // devaluation period in blocks
			ether('100000'), // debt limit
			[mainAssetOracleType], // enabled oracles
			0,
			0,
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
				0,
				0,
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
				0,
				0,
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
		deploy,
		updatePrice,
		repay,
		expectRevert,
	}
}
