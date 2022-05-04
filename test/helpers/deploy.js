const {createDeployment: createWrappedSLPDeployment} = require("../../lib/deployments/wrappedSLP");
const {createDeployment: createWrappedSSLPDeployment} = require("../../lib/deployments/wrappedSSLP");
const {createDeployment: createCoreDeployment} = require("../../lib/deployments/core");
const {runDeployment, loadHRE} = require("../helpers/deployUtils");
const {ethers} = require("hardhat");
const {attachContract, deployContract, Q112} = require("./ethersUtils");
const {ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN,
    ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX,
    ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX
} = require("../../lib/constants");
const UniswapV2FactoryDeployCode = require("./UniswapV2DeployCode");
const {ZERO_ADDRESS} = require("./deployUtils");
const EthersBN = ethers.BigNumber.from;
const ether = ethers.utils.parseUnits;

const BASE_BORROW_FEE = EthersBN('123'); // 123 basis points = 1.23% = 0.0123
const BASIS_POINTS_IN_1 = EthersBN('10000'); // 1 = 100.00% = 10000 basis points
const BORROW_FEE_RECEIVER_ADDRESS = '0x0000000000000000000000000000000123456789';

const SHIBA_TOPDOG_BONES_PER_BLOCK = ether("50");
const SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT = EthersBN("33");

const SUSHI_MASTERCHEF_SUSHI_PER_BLOCK = ether("100");

const CASE_WRAPPED_TO_UNDERLYING_CHAINLINK = 1;
const CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN = 2;
const CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX = 3;
const CASE_CHAINLINK = 4;
const CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX = 5;
const CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX = 6;

const PREPARE_ORACLES_METHODS = {
    [CASE_WRAPPED_TO_UNDERLYING_CHAINLINK]: prepareWrappedToUnderlyingOracle,
    [CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX]: prepareWrappedToUnderlyingOracleKeydonix,
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN]: prepareWrappedToUnderlyingOracleWrappedLPToken,
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX]: prepareWrappedToUnderlyingOracleWrappedLPTokenKeydonix,
    [CASE_CHAINLINK]: prepareChainlinkOracle,
    [CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX]: prepareUniswapV2MainAssetOracleKeydonix,
}

/**
 * context:
 * - collateral - collateral to get usdp from, must be set in prepareOracle
 * - collateralOracleType - oracle type for collateral, must be set in prepareOracle
 * - collateralUnderlying - the lowest level token in meta oracles, for example
 *   - wrapped to underlying - underlying token
 *   - pool token - one of the pool tokens (not weth)
 *   - wrapped to underlying where underlying one is pool token - one of the pool tokens (not weth)
 * - collateralWrappedAssetUnderlying - underlying token of wrapped asset
 *
 * - isKeydonix - need to pass additional keydonix proofs
 *
 * built-in prices:
 * - usd/weth = 250
 * - any other asset/usd = 500
 *
 * @param _oracleCase - case for oracle preparation, see CASE_* constants
 */
async function prepareCoreContracts(context, _oracleCase, oracleParams = {}) {
    if (!context.deployer) {
        context.deployer = (await ethers.getSigners())[0]
    }

    context.weth = await deployContract("WETHMock");
    context.foundation = await deployContract("FoundationMock");

    const deployedAddresses = await deployCore(context);

    context.usdp = await attachContract("USDPMock", deployedAddresses.USDPMock); // for tests we deploy USDPMock
    context.vaultParameters = await attachContract("VaultParameters", deployedAddresses.VaultParameters);
    context.vault = await attachContract("Vault", deployedAddresses.Vault);
    context.oracleRegistry = await attachContract("OracleRegistry", deployedAddresses.OracleRegistry);
    context.assetsBooleanParameters = await attachContract("AssetsBooleanParameters", deployedAddresses.AssetsBooleanParameters);
    context.chainlinkOracleMainAsset = await attachContract("ChainlinkedOracleMainAsset", deployedAddresses.ChainlinkedOracleMainAsset);
    context.wrappedToUnderlyingOracle = await attachContract("WrappedToUnderlyingOracle", deployedAddresses.WrappedToUnderlyingOracle);
    context.vaultManagerParameters = await attachContract("VaultManagerParameters", deployedAddresses.VaultManagerParameters);
    context.liquidationAuction = await attachContract("LiquidationAuction02", deployedAddresses.LiquidationAuction02);
    context.swappersRegistry = await attachContract("SwappersRegistry", deployedAddresses.SwappersRegistry);

    context.cdpManager = await attachContract("CDPManager01", deployedAddresses.CDPManager01);
    context.cdpManagerKeydonix = await attachContract("CDPManager01_Fallback", deployedAddresses.CDPManager01_Fallback);

    context.chainLinkEthUsdAggregator = await deployContract("ChainlinkAggregator_Mock", 250e8, 8); // 250usd/eth
    await context.oracleRegistry.setOracleTypeForAsset(context.weth.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    context.chainlinkOracleMainAsset.setAggregators(
        [context.weth.address],
        [context.chainLinkEthUsdAggregator.address],
        [], [],
    )

    context.swapper = await deployContract("SwapperMock", context.usdp.address);
    await context.swappersRegistry.add(context.swapper.address)

    if (_oracleCase) {
        await prepareOracle(context, _oracleCase, oracleParams);

        await context.vaultManagerParameters.setCollateral(
            context.collateral.address,
            '0', // stability fee // todo replace in tests for stability dee
            '13', // liquidation fee
            '75', // initial collateralization
            '76', // liquidation ratio
            '0', // liquidation discount (3 decimals)
            '100', // devaluation period in blocks
            ether('100000'), // debt limit
            [context.collateralOracleType], // enabled oracles
            0,
            0,
        );
    }
}

/**
 * @param _oracleCase - case for oracle preparation, see CASE_* constants
 * 
 * context:
 * - bonesFeeReceiver
 */
async function prepareWrappedSSLP(context, _oracleCase) {
    await prepareCoreContracts(context); // oracles will be prepared below

    context.tokenA = await deployContract("EmptyToken", 'TokenA descr', 'tokenA', 18, ether('100'), context.deployer.address);
    context.tokenB = await deployContract("EmptyToken", 'TokenB descr', 'tokenB', 16, ether('100'), context.deployer.address);
    context.tokenC = await deployContract("EmptyToken", 'TokenC descr', 'tokenC', 12, ether('100'), context.deployer.address);
    context.tokenD = await deployContract("EmptyToken", 'TokenD descr', 'tokenD', 14, ether('100'), context.deployer.address);

    context.sslpToken0 = await deployContract("SushiSwapLpToken_Mock", context.tokenA.address, context.tokenB.address, 'SushiSwap LP0', 'SSLP0', 18);
    context.sslpToken1 = await deployContract("SushiSwapLpToken_Mock", context.tokenC.address, context.tokenD.address, 'SushiSwap LP1', 'SSLP1', 17);

    context.boneToken = await deployContract("BoneToken_Mock");
    context.boneLocker1 = await deployContract("BoneLocker_Mock", context.boneToken.address, "0x0000000000000000000000000000000000001234", 1, 3);
    context.topDog = await deployContract(
        "TopDog_Mock",
        context.boneToken.address,
        context.boneLocker1.address,
        "0x0000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000002",
        "0x0000000000000000000000000000000000000003",
        "0x0000000000000000000000000000000000000004",
        SHIBA_TOPDOG_BONES_PER_BLOCK,
        1,
        2,
        SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT,
        100
    );
    await context.topDog.add(50, context.sslpToken0.address, false);
    await context.topDog.add(50, context.sslpToken1.address, false);
    await context.boneLocker1.transferOwnership(context.topDog.address);
    await context.boneToken.transferOwnership(context.topDog.address);

    const deployedAddresses0 = await deployWrappedSSLP(context, 0);
    context.wrappedSslp0 = await attachContract("WrappedShibaSwapLp", deployedAddresses0.WrappedShibaSwapLp)
    await context.wrappedSslp0.setFee(0); // to simplify most tests. Fee must be tested separately

    const deployedAddresses1 = await deployWrappedSSLP(context, 1);
    context.wrappedSslp1 = await attachContract("WrappedShibaSwapLp", deployedAddresses1.WrappedShibaSwapLp)
    await context.wrappedSslp1.setFee(0); // to simplify most tests. Fee must be tested separately

    await prepareOracle(context, _oracleCase, {
        collateral: context.wrappedSslp0,
        collateralUnderlying: await attachContract('IERC20', await context.sslpToken0.token0()),
        collateralWrappedAssetUnderlying: context.sslpToken0,
    });

    await context.vaultManagerParameters.setCollateral(
        context.collateral.address,
        '0', // stability fee // todo replace in tests for stability dee
        '13', // liquidation fee
        '75', // initial collateralization
        '76', // liquidation ratio
        '0', // liquidation discount (3 decimals)
        '100', // devaluation period in blocks
        ether('100000'), // debt limit
        [context.collateralOracleType], // enabled oracles
        0,
        0,
    );
}

/**
 * @param _oracleCase - case for oracle preparation, see CASE_* constants
 *
 */
async function prepareWrappedSLP(context, _oracleCase) {
    await prepareCoreContracts(context); // oracles will be prepared below

    context.tokenA = await deployContract("EmptyToken", 'TokenA descr', 'tokenA', 18, ether('100'), context.deployer.address);
    context.tokenB = await deployContract("EmptyToken", 'TokenB descr', 'tokenB', 16, ether('100'), context.deployer.address);
    context.tokenC = await deployContract("EmptyToken", 'TokenC descr', 'tokenC', 12, ether('100'), context.deployer.address);
    context.tokenD = await deployContract("EmptyToken", 'TokenD descr', 'tokenD', 14, ether('100'), context.deployer.address);

    context.lpToken0 = await deployContract("SushiSwapLpToken_Mock", context.tokenA.address, context.tokenB.address, 'SushiSwap LP0', 'SSLP0', 18);
    context.lpToken1 = await deployContract("SushiSwapLpToken_Mock", context.tokenC.address, context.tokenD.address, 'SushiSwap LP1', 'SSLP1', 17);

    context.rewardToken = await deployContract("SushiToken_Mock");
    context.rewardDistributor = await deployContract(
        "MasterChef_Mock",
        context.rewardToken.address,
        "0x0000000000000000000000000000000000000001",
        SUSHI_MASTERCHEF_SUSHI_PER_BLOCK,
        1,
        2,
    );
    await context.rewardDistributor.add(50, context.lpToken0.address, false);
    await context.rewardDistributor.add(50, context.lpToken1.address, false);
    await context.rewardToken.transferOwnership(context.rewardDistributor.address);

    context.wslpFactory = await attachContract("WSLPFactory", (await deployWrappedSLP(context)).WSLPFactory);

    await context.wslpFactory.deploy(0);
    context.wrappedSlp0 = await attachContract("WrappedSushiSwapLp", await context.wslpFactory.wrappedLpByPoolId(0));

    await context.wslpFactory.deploy(1);
    context.wrappedSlp1 = await attachContract("WrappedSushiSwapLp", await context.wslpFactory.wrappedLpByPoolId(1))

    await prepareOracle(context, _oracleCase, {
        collateral: context.wrappedSlp0,
        collateralUnderlying: await attachContract('IERC20', await context.lpToken0.token0()),
        collateralWrappedAssetUnderlying: context.lpToken0,
    });

    await context.vaultManagerParameters.setCollateral(
        context.collateral.address,
        '0', // stability fee // todo replace in tests for stability dee
        '13', // liquidation fee
        '75', // initial collateralization
        '76', // liquidation ratio
        '0', // liquidation discount (3 decimals)
        '100', // devaluation period in blocks
        ether('100000'), // debt limit
        [context.collateralOracleType], // enabled oracles
        0,
        0,
    );
}

async function deployCore(context) {
    const deployment = await createCoreDeployment({
        deployer: context.deployer.address,
        foundation: context.foundation.address,
        manager: context.deployer.address,
        wtoken: context.weth.address,
        baseBorrowFeePercent: 0, // todo must be set in tests for borrow fee
        borrowFeeReceiver: BORROW_FEE_RECEIVER_ADDRESS,
        testEnvironment: true,
    });
    const hre = await loadHRE();
    return await runDeployment(deployment, {hre, deployer: context.deployer.address});
}

async function deployWrappedSSLP(context, topDogPoolId) {
    const deployment = await createWrappedSSLPDeployment({
        deployer: context.deployer.address,
        manager: context.manager.address,
        vaultParameters: context.vaultParameters.address,
        topDog: context.topDog.address,
        topDogPoolId: topDogPoolId,
        feeReceiver: context.bonesFeeReceiver.address,
    });
    const hre = await loadHRE();
    return await runDeployment(deployment, {hre, deployer: context.deployer.address});
}

async function deployWrappedSLP(context) {
    const deployment = await createWrappedSLPDeployment({
        deployer: context.deployer.address,
        manager: context.manager.address,
        vaultParameters: context.vaultParameters.address,
        rewardDistributor: context.rewardDistributor.address,
        feeReceiver: ZERO_ADDRESS,
        feePercent: 0 // todo must be set in tests for fee
    });
    const hre = await loadHRE();
    return await runDeployment(deployment, {hre, deployer: context.deployer.address});
}

/**
 * @param _oracleCase - case for oracle preparation, see CASE_* constants
 * @param params - values to overwrite context
 *  - collateral
 *  - collateralUnderlying
 *  - collateralWrappedAssetUnderlying
 *  could be fn, context must be passed
 */
async function prepareOracle(context, _oracleCase, params = {}) {
    if (typeof params.collateral == 'function') { // todo other vars
        params.collateral = params.collateral(context)
    }
    await PREPARE_ORACLES_METHODS[_oracleCase](context, params);
}

async function prepareWrappedToUnderlyingOracle(context, {collateral}) {
    // todo check if curveLpOracle exist as additional oracle case (see WrappedToUnderlyingOracle section in utils)

    // wrapped token
    context.collateral = collateral ?? await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING;
    // real token
    context.collateralUnderlying = await deployContract("DummyToken", "STAKE clone", "STAKE", 18, ether('1000000'));
    context.collateralWrappedAssetUnderlying = context.collateralUnderlying; // in case of usage with wrapped assets

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING);
    await context.wrappedToUnderlyingOracle.setUnderlying(context.collateral.address, context.collateralUnderlying.address)

    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 500e8.toString(), 8);
    await context.chainlinkOracleMainAsset.setAggregators(
        [context.collateralUnderlying.address], [chainlinkAggregator.address],
        [], []
    );
}

async function prepareWrappedToUnderlyingOracleKeydonix(context, {collateral}) {
    // wrapped token
    context.collateral = collateral ?? await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX;
    context.collateralUnderlying = await deployContract("DummyToken", "STAKE clone", "STAKE", 18, ether('1000000'));
    context.collateralWrappedAssetUnderlying = context.collateralUnderlying; // in case of usage with wrapped assets

    const wrappedToUnderlyingOracleKeydonix = await deployContract('WrappedToUnderlyingOracleKeydonix', context.vaultParameters.address, context.oracleRegistry.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, wrappedToUnderlyingOracleKeydonix.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX);
    await wrappedToUnderlyingOracleKeydonix.setUnderlying(context.collateral.address, context.collateralUnderlying.address)

    const oracleKeydonix = await deployContract('KeydonixSimpleOracle_Mock');
    await oracleKeydonix.setRate(Q112.mul(500));
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX, oracleKeydonix.address); // just some keydonix type
    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX);

    await context.oracleRegistry.setKeydonixOracleTypes([
        ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX,
        ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX
    ]);
}

/**
 * here in fact underlyingAsset is must be used as pool, but for oracle purposes we will create new pool (since we use mock for lp)
 *
 * 1 eth = 250 usd, 1 underlying token = 250 usd, so 1 lp token = 500 usd (250+250)
 */
async function prepareWrappedToUnderlyingOracleWrappedLPToken(context, {collateral, collateralUnderlying, collateralWrappedAssetUnderlying}) {
    context.collateral = collateral;
    context.collateralUnderlying = collateralUnderlying;
    context.collateralWrappedAssetUnderlying = collateralWrappedAssetUnderlying;

    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING;

    const [uniswapFactory, poolAddress] = await prepareUniswapV2Pool(context, context.collateralUnderlying);

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING);
    await context.wrappedToUnderlyingOracle.setUnderlying(context.collateral.address, poolAddress);

    const oraclePoolToken = await deployContract('OraclePoolToken_Mock', context.oracleRegistry.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN, oraclePoolToken.address)
    await context.oracleRegistry.setOracleTypeForAsset(poolAddress, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN);

    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 250e8.toString(), 8);
    await context.chainlinkOracleMainAsset.setAggregators(
        [context.collateralUnderlying.address], [chainlinkAggregator.address],
        [], []
    );
}

/**
 * here in fact underlyingAsset is must be used as pool, but for oracle purposes we will create new pool (since we use mock for lp)
 *
 * 1 eth = 250 usd, 1 underlying token = 250 usd, so 1 lp token = 500 usd (250+250)
 */
async function prepareWrappedToUnderlyingOracleWrappedLPTokenKeydonix(context, {collateral, collateralUnderlying, collateralWrappedAssetUnderlying}) {
    context.collateral = collateral;
    context.collateralUnderlying = collateralUnderlying;
    context.collateralWrappedAssetUnderlying = collateralWrappedAssetUnderlying;

    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX;

    const [uniswapFactory, poolAddress] = await prepareUniswapV2Pool(context, context.collateralUnderlying);

    const oracleKeydonixWrappedToUnderlying = await deployContract('WrappedToUnderlyingOracleKeydonix', context.vaultParameters.address, context.oracleRegistry.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, oracleKeydonixWrappedToUnderlying.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX);
    await oracleKeydonixWrappedToUnderlying.setUnderlying(context.collateral.address, poolAddress)

    const oracleKeydonixMainAsset = await deployContract('KeydonixOracleMainAsset_Mock', uniswapFactory.address, context.weth.address, context.chainLinkEthUsdAggregator.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX, oracleKeydonixMainAsset.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX);

    const oracleKeydonixPoolToken = await deployContract('KeydonixOraclePoolToken_Mock', oracleKeydonixMainAsset.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX, oracleKeydonixPoolToken.address);
    await context.oracleRegistry.setOracleTypeForAsset(poolAddress, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX);

    await context.oracleRegistry.setKeydonixOracleTypes([
        ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX,
        ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX,
        ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX,
    ]);
}

async function prepareChainlinkOracle(context, {collateral}) {
    context.collateral = collateral ?? await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_CHAINLINK_MAIN_ASSET;

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, context.collateralOracleType);

    if (context.collateral !== context.weth) { // for weth we already have set aggregator
        const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 500e8.toString(), 8);
        await context.chainlinkOracleMainAsset.setAggregators(
            [context.collateral.address], [chainlinkAggregator.address],
            [], []
        );
    }
}

async function prepareUniswapV2MainAssetOracleKeydonix(context, {collateral}) {
    context.collateral = collateral ?? await deployContract("DummyToken", "Token", "token", 18, ether('100000'));
    context.collateralOracleType = ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX;

    // pool token/eth. 1eth=$250. with deposit 0.5 token vs 1 eth we will have 1 token = 2*eth price = 500
    const [uniswapFactory, poolAddress] = await prepareUniswapV2Pool(context, context.collateral, '0.5');

    const oracleKeydonixMainAsset = await deployContract('KeydonixOracleMainAsset_Mock', uniswapFactory.address, context.weth.address, context.chainLinkEthUsdAggregator.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX, oracleKeydonixMainAsset.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX);

    await context.oracleRegistry.setKeydonixOracleTypes([
        ORACLE_TYPE_UNISWAP_V2_MAIN_ASSET_KEYDONIX,
    ]);
}

async function prepareUniswapV2Pool(context, token, tokenAmountToPool = 1) {
    const deployResult = await context.deployer.sendTransaction({
        data: UniswapV2FactoryDeployCode
    });

    const uniswapFactory = await attachContract("IUniswapV2Factory", deployResult.creates)
    const uniswapRouter = await deployContract('UniswapV2Router02', uniswapFactory.address, context.weth.address)

    await context.weth.deposit({value: ether('1')});

    await poolDeposit(context, uniswapRouter, token, tokenAmountToPool);

    return [
        uniswapFactory,
        await uniswapFactory.getPair(context.weth.address, token.address),
    ]
}

async function poolDeposit(context, uniswapRouter, token, tokenAmountToPool) {
    tokenAmountToPool = ether(tokenAmountToPool.toString());
    const ethAmount = ether('1');
    await token.approve(uniswapRouter.address, tokenAmountToPool);
    await context.weth.approve(uniswapRouter.address, ethAmount);
    await uniswapRouter.addLiquidity(
        token.address,
        context.weth.address,
        tokenAmountToPool,
        ethAmount,
        tokenAmountToPool,
        ethAmount,
        context.deployer.address,
        1e18.toString(), // deadline
    );
}

module.exports = {
    prepareCoreContracts,
    prepareWrappedSSLP,
    prepareWrappedSLP,

    SHIBA_TOPDOG_BONES_PER_BLOCK,
    SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT,

    SUSHI_MASTERCHEF_SUSHI_PER_BLOCK,

    CASE_WRAPPED_TO_UNDERLYING_CHAINLINK,
    CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN,
    CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX,
    CASE_CHAINLINK,
    CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX,
    CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX,
}
