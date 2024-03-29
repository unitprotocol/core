const Vault = artifacts.require('Vault');
const VaultParameters = artifacts.require('VaultParameters');
const FoundationMock = artifacts.require('FoundationMock');
const VaultManagerParameters = artifacts.require('VaultManagerParameters');
const VaultManagerBorrowFeeParameters = artifacts.require('VaultManagerBorrowFeeParameters');
const SwappersRegistry = artifacts.require('SwappersRegistry');
const USDP = artifacts.require('USDPMock');
const WETH = artifacts.require('WETHMock');
const DummyToken = artifacts.require('DummyToken');
const CyWETH = artifacts.require('CyWETH');
const YvWETH = artifacts.require('YvWETH');
const WstETH = artifacts.require('WstETH');
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
const AssetsBooleanParameters = artifacts.require('AssetsBooleanParameters');
const CollateralRegistry = artifacts.require('CollateralRegistry');
const CyTokenOracle = artifacts.require('CyTokenOracle');
const YvTokenOracle = artifacts.require('YvTokenOracle');
const WstEthOracle = artifacts.require('WstEthOracle');
const StETHPriceFeed = artifacts.require('StETHPriceFeed');
const StETHStableSwapOracle = artifacts.require('StETHStableSwapOracle');
const StETHCurvePool = artifacts.require('StETHCurvePool');

const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce, deployContractBytecode, runDeployment, loadHRE } = require('./deployUtils');
const { createDeployment } = require('../../lib/deployments/core');
const BN = web3.utils.BN;
const { expect } = require('chai');
const getWrapper = require('./wrappers');
const {PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION} = require("../../lib/constants");

const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const BASE_BORROW_FEE = new BN(123); // 123 basis points = 1.23% = 0.0123
const BASIS_POINTS_IN_1 = new BN('10000'); // 1 = 100.00% = 10000 basis points
const BORROW_FEE_RECEIVER_ADDRESS = '0x0000000000000000000000000000000123456789';


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

function resetNonceCache() {
    if (undefined === web3.currentProvider.engine)
        return;

	for (const subProvider of web3.currentProvider.engine._providers)
		if ('nonceCache' in subProvider)
			subProvider.nonceCache = {};
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

	const repayAllAndWithdrawEth = async (user) => {
		const totalDebt = await context.vault.getTotalDebt(context.weth.address, user);

		// mint usdp to cover initial borrow fee
		await context.usdp.tests_mint(user, calcBorrowFee(totalDebt));

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
	  resetNonceCache();  // may be needed after the previous test case execution

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
		// run with: USE_DEPLOYMENT=1 npx hardhat test
		if (useDeployment) {
			const deployment = await createDeployment({
				deployer: context.deployer,
				foundation: context.foundation.address,
				manager: context.deployer,
				wtoken: context.weth.address,
				baseBorrowFeePercent: 123,  // BASE_BORROW_FEE, their fckn BNs are incompatible
				borrowFeeReceiver: BORROW_FEE_RECEIVER_ADDRESS,
			  testEnvironment: true,
			});
			const hre = await loadHRE();
			const deployed = await runDeployment(deployment, {hre, deployer: context.deployer});
			context.deployed = deployed;

			context.usdp = await USDP.at(deployed.USDPMock); // for tests we deploy USDPMock even with deploy script
			context.vaultParameters = await VaultParameters.at(deployed.VaultParameters);
			context.vault = await Vault.at(deployed.Vault);
			context.oracleRegistry = await OracleRegistry.at(deployed.OracleRegistry);
			context.assetsBooleanParameters = await AssetsBooleanParameters.at(deployed.AssetsBooleanParameters);
			context.chainlinkOracleMainAsset = await ChainlinkOracleMainAsset.at(deployed.ChainlinkedOracleMainAsset);

			// This web3 doesn't care about cache invalidation and non-trivial workflows, so we'll do it the hard way.
			resetNonceCache();
		} else {
			const vaultParametersAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
			context.usdp = await USDP.new(vaultParametersAddr);

			const vaultAddr = calculateAddressAtNonce(context.deployer, await web3.eth.getTransactionCount(context.deployer) + 1);
			context.vaultParameters = await VaultParameters.new(vaultAddr, context.foundation.address);

			context.vault = await Vault.new(context.vaultParameters.address, '0x0000000000000000000000000000000000000000', context.usdp.address, context.weth.address);

			context.oracleRegistry = await OracleRegistry.new(context.vaultParameters.address, context.weth.address)

			context.assetsBooleanParameters = await AssetsBooleanParameters.new(context.vaultParameters.address, [], []);
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
			await context.oracleRegistry.setOracle(mainAssetOracleType, context.keydonixOracleMainAssetMock.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)
			if (isLP) {
				context.keydonixOraclePoolTokenMock = await KeydonixOraclePoolTokenMock.new(
					context.keydonixOracleMainAssetMock.address
				)
				await context.oracleRegistry.setOracle(poolTokenOracleType, context.keydonixOraclePoolTokenMock.address)
				await context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
				oracleTypes.push(poolTokenOracleType)
			}
			await context.oracleRegistry.setKeydonixOracleTypes(oracleTypes)
		} else if (uniswapKeep3r || sushiswapKeep3r) {
			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			);
			if (uniswapKeep3r) {
				mainAssetOracleType = 3
				await context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address)
				await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 4
					await context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
					await context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
				}
			} else if (sushiswapKeep3r) {
				mainAssetOracleType = 7
				await context.oracleRegistry.setOracle(mainAssetOracleType, context.keep3rOracleMainAssetMock.address)
				await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

				if (isLP) {
					poolTokenOracleType = 8
					await context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
					await context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
				}
			}
		} else if (chainlink) {
			mainAssetOracleType = 5
			poolTokenOracleType = 6

			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, mainAssetOracleType)

			if (isLP) {
				poolTokenOracleType = 6
				await context.oracleRegistry.setOracle(poolTokenOracleType, context.oraclePoolToken.address)
				await context.oracleRegistry.setOracleTypeForAsset(context.poolToken.address, poolTokenOracleType)
			}

		} else if (bearingAssetSimple) {
			mainAssetOracleType = 9

			context.bearingAsset = await DummyToken.new("Bearing Asset", "BeA", 18, ether('1000'));

			context.keep3rOracleMainAssetMock = await Keep3rOracleMainAssetMock.new(
				context.uniswapFactory.address,
				context.weth.address,
				context.ethUsd.address,
			)

			await context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.bearingAssetOracle = await BearingAssetOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			await context.bearingAssetOracle.setUnderlying(context.bearingAsset.address, context.mainCollateral.address)

			await context.oracleRegistry.setOracle(mainAssetOracleType, context.bearingAssetOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.bearingAsset.address, 9)


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

			await context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset1.address, 5)
			await context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset2.address, 5)
			await context.oracleRegistry.setOracleTypeForAsset(context.curveLockedAsset3.address, 5)

			await context.oracleRegistry.setOracle(10, context.curveLpOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 10)

			context.wrappedAsset = await DummyToken.new("Wrapper Curve LP", "WCLP", 18, ether('100000000000'))

			await context.assetsBooleanParameters.set(context.wrappedAsset.address, PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, true);

			await context.wrappedToUnderlyingOracle.setUnderlying(context.wrappedAsset.address, context.mainCollateral.address)

			await context.oracleRegistry.setOracle(mainAssetOracleType, context.wrappedToUnderlyingOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.wrappedAsset.address, mainAssetOracleType)

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

			await context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.CyTokenOracle = await CyTokenOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
				[cyTokenImplementation],
			)

			await context.oracleRegistry.setOracle(mainAssetOracleType, context.CyTokenOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.CyTokenOracle.address, 14)

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

			await context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

			context.YvTokenOracle = await YvTokenOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
			)

			await context.oracleRegistry.setOracle(mainAssetOracleType, context.YvTokenOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.YvTokenOracle.address, 15)

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

			await context.oracleRegistry.setOracle(7, context.keep3rOracleMainAssetMock.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.mainCollateral.address, 7)

      // let stEthDecimals = 18;
			context.WstEthOracle = await WstEthOracle.new(
				context.vaultParameters.address,
				context.oracleRegistry.address,
				context.wstETH.address,
				context.stETHPriceFeed.address,
			)

			await context.oracleRegistry.setOracle(mainAssetOracleType, context.WstEthOracle.address)
			await context.oracleRegistry.setOracleTypeForAsset(context.WstEthOracle.address, 16)

		}

		if (useDeployment) {
			context.collateralRegistry = await CollateralRegistry.at(context.deployed.CollateralRegistry);
			context.cdpRegistry = await CDPRegistry.at(context.deployed.CDPRegistry);
			context.vaultManagerParameters = await VaultManagerParameters.at(context.deployed.VaultManagerParameters);
			context.vaultManagerBorrowFeeParameters = await VaultManagerBorrowFeeParameters.at(context.deployed.VaultManagerBorrowFeeParameters);
			context.swappersRegistry = await SwappersRegistry.at(context.deployed.SwappersRegistry);
		}
		else {
			context.collateralRegistry = await CollateralRegistry.new(context.vaultParameters.address, [context.mainCollateral.address]);
			context.cdpRegistry = await CDPRegistry.new(context.vault.address, context.collateralRegistry.address);
			context.vaultManagerParameters = await VaultManagerParameters.new(context.vaultParameters.address);
			context.vaultManagerBorrowFeeParameters = await VaultManagerBorrowFeeParameters.new(context.vaultParameters.address, BASE_BORROW_FEE, BORROW_FEE_RECEIVER_ADDRESS);
			await context.vaultParameters.setManager(context.vaultManagerParameters.address, true);

			context.swappersRegistry = await SwappersRegistry.new(context.vaultParameters.address);
		}

		if (useDeployment) {
			context.liquidationAuction = await LiquidationAuction.at(context.deployed.LiquidationAuction02);
		} else {
			context.liquidationAuction = await LiquidationAuction.new(
				context.vaultManagerParameters.address,
				context.cdpRegistry.address,
				context.assetsBooleanParameters.address
			);
		}

		if (keydonix) {
			context.vaultManagerKeydonix = await CDPManagerFallback.new(
				context.vaultManagerParameters.address,
				context.vaultManagerBorrowFeeParameters.address,
				context.oracleRegistry.address,
				context.cdpRegistry.address,
				context.swappersRegistry.address
			);
		}

		if (useDeployment) {
			context.vaultManager = await CDPManager.at(context.deployed.CDPManager01);
		} else {
			context.vaultManager = await CDPManager.new(
				context.vaultManagerParameters.address, context.vaultManagerBorrowFeeParameters.address,
				context.oracleRegistry.address, context.cdpRegistry.address, context.swappersRegistry.address
			);
		}


		if (keydonix) {
			await context.vaultParameters.setVaultAccess(context.vaultManagerKeydonix.address, true);
		}

		if (!useDeployment) {
			await context.vaultParameters.setVaultAccess(context.vaultManager.address, true);
			await context.vaultParameters.setVaultAccess(context.liquidationAuction.address, true);
		}

		let minColPercent, maxColPercent
		if (keydonix) {
			minColPercent = 3
			maxColPercent = 5
		} else {
			minColPercent = 0
			maxColPercent = 0
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

	const calcBorrowFee = (usdpAmount) => {
		return usdpAmount.mul(BASE_BORROW_FEE).div(BASIS_POINTS_IN_1)
	};

	return {
		poolDeposit,
		approveCollaterals: context.approveCollaterals,
		join: w.join,
		joinEth: w.joinEth,
		buyout,
		triggerLiquidation: w.triggerLiquidation,
		exit: w.exit,
		exitTarget: w.exitTarget,
		exitEth: w.exitEth,
		repayAllAndWithdraw: w.repayAllAndWithdraw,
		repayAllAndWithdrawEth,
		deploy,
		updatePrice,
		repay,
		expectRevert,
		calcBorrowFee,
		BORROW_FEE_RECEIVER_ADDRESS,
		MAX_UINT
	}
}
