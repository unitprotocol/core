const {createDeployment: createWrappedSSLPDeployment} = require("../../lib/deployments/wrappedSSLP");
const {createDeployment: createCoreDeployment} = require("../../lib/deployments/core");
const {runDeployment, loadHRE} = require("../helpers/deployUtils");
const {ethers} = require("hardhat");
const {attachContract, deployContract} = require("./ethersUtils");
const {ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN,
    ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_POOL_TOKEN,
    ORACLE_TYPE_UNISWAP_V2_KEYDONIX_MAIN_ASSET
} = require("../../lib/constants");
const UniswapV2FactoryDeployCode = require("./UniswapV2DeployCode");
const EthersBN = ethers.BigNumber.from;
const ether = ethers.utils.parseUnits;

const BASE_BORROW_FEE = EthersBN('123'); // 123 basis points = 1.23% = 0.0123
const BASIS_POINTS_IN_1 = EthersBN('10000'); // 1 = 100.00% = 10000 basis points
const BORROW_FEE_RECEIVER_ADDRESS = '0x0000000000000000000000000000000123456789';

const SHIBA_TOPDOG_BONES_PER_BLOCK = ether("50");
const SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT = EthersBN("33");

const CASE_WRAPPED_TO_UNDERLYING_SIMPLE = 1;
const CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN = 2;
const CASE_KEYDONIX_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN = 3;

const PREPARE_ORACLES_METHODS = {
    [CASE_WRAPPED_TO_UNDERLYING_SIMPLE]: prepareWrappedToUnderlyingOracle,
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN]: prepareWrappedToUnderlyingOracleWrappedLPToken,
    [CASE_KEYDONIX_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN]: prepareKeydonixWrappedToUnderlyingOracleWrappedLPToken,
}

/**
 * context:
 * - collateral - collateral to get usdp from, must be set in prepareOracle
 * - collateralOracleType - oracle type for collateral, must be set in prepareOracle
 * - collateralUnderlying - the lowest level token in meta oracles, for example
 *   - wrapped to underlying - underlying token
 *   - pool token - one of the pool tokens (not weth)
 *   - wrapped to underlying where underlying one is pool token - one of the pool tokens (not weth)
 *
 * - isKeydonix - need to pass additional keydonix proofs
 *
 *
 * @param _oracle_case - case for oracle preparation, see CASE_* constants
 */
async function prepareCoreContracts(context, _oracle_case) {
    if (!context.deployer) {
        context.deployer = (await ethers.getSigners())[0]
    }

    context.weth = await deployContract("WETH");
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

    context.cdpManager = await attachContract("CDPManager01", deployedAddresses.CDPManager01);
    context.cdpManagerKeydonix = await attachContract("CDPManager01_Fallback", deployedAddresses.CDPManager01_Fallback);

    context.chainLinkEthUsdAggregator = await deployContract("ChainlinkAggregator_Mock", 250e8, 8); // 250usd/eth
    await context.oracleRegistry.setOracleTypeForAsset(context.weth.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    context.chainlinkOracleMainAsset.setAggregators(
        [context.weth.address],
        [context.chainLinkEthUsdAggregator.address],
        [], [],
    )

    if (_oracle_case) {
        await prepareOracle(context, _oracle_case);
    }
}

/**
 * @param _oracle_case - case for oracle preparation, see CASE_* constants
 */
async function prepareWrappedSSLP(context, _oracle_case) {
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
    await context.wrappedSslp0.approveSslpToTopdog();

    const deployedAddresses1 = await deployWrappedSSLP(context, 1);
    context.wrappedSslp1 = await attachContract("WrappedShibaSwapLp", deployedAddresses1.WrappedShibaSwapLp)
    await context.wrappedSslp1.approveSslpToTopdog();

    await prepareOracle(context, _oracle_case, {
        wrappedAsset: context.wrappedSslp0,
        underlyingAsset: context.sslpToken0
    });

    await context.vaultManagerParameters.setCollateral(
        context.collateral.address,
        '0', // stability fee // todo replace in tests for stability dee
        '13', // liquidation fee
        '67', // initial collateralization
        '68', // liquidation ratio
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
    });
    const hre = await loadHRE();
    return await runDeployment(deployment, {hre, deployer: context.deployer.address});
}

/**
 * @param _oracle_case - case for oracle preparation, see CASE_* constants
 */
async function prepareOracle(context, _oracle_case, params = {}) {
    await PREPARE_ORACLES_METHODS[_oracle_case](context, params);
}

async function prepareWrappedToUnderlyingOracle(context) {
    // todo check if curveLpOracle exist as additional oracle case (see WrappedToUnderlyingOracle section in utils)

    // wrapped token
    context.collateral = await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING;
    // real token
    context.collateralUnderlying = await deployContract("DummyToken", "STAKE clone", "STAKE", 18, ether('1000000'));

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING);
    await context.wrappedToUnderlyingOracle.setUnderlying(context.collateral.address, context.collateralUnderlying.address)

    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 1e8.toString(), 8);
    await context.chainlinkOracleMainAsset.setAggregators(
        [context.collateralUnderlying.address], [chainlinkAggregator.address],
        [], []
    );
}

/**
 * here in fact underlyingAsset is must be used as pool, but for oracle purposes we will create new pool (since we use mock for lp)
 *
 * for convenience 1 eth = 0.5 usd, 1 underlying token = 0.5 usd, so 1 lp token = 1 usd
 */
async function prepareWrappedToUnderlyingOracleWrappedLPToken(context, {wrappedAsset, underlyingAsset}) {
    context.collateral = wrappedAsset;
    context.collateralUnderlying = await attachContract('IERC20', await underlyingAsset.token0());

    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING;

    const [uniswapFactory, poolAddress] = await prepareUniswapV2Pool(context);

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING);
    await context.wrappedToUnderlyingOracle.setUnderlying(context.collateral.address, poolAddress);

    const oraclePoolToken = await deployContract('OraclePoolToken_Mock', context.oracleRegistry.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN, oraclePoolToken.address)
    await context.oracleRegistry.setOracleTypeForAsset(poolAddress, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN);

    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 5e7.toString(), 8);
    await context.chainlinkOracleMainAsset.setAggregators(
        [context.collateralUnderlying.address], [chainlinkAggregator.address],
        [], []
    );
}

async function prepareKeydonixWrappedToUnderlyingOracleWrappedLPToken(context, {wrappedAsset, underlyingAsset}) {
    context.collateral = wrappedAsset;
    context.collateralUnderlying = await attachContract('IERC20', await underlyingAsset.token0());

    context.collateralOracleType = ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING;

    const [uniswapFactory, poolAddress] = await prepareUniswapV2Pool(context);

    const oracleKeydonixWrappedToUnderlying = await deployContract('WrappedToUnderlyingOracleKeydonix', context.vaultParameters.address, context.oracleRegistry.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING, oracleKeydonixWrappedToUnderlying.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING);
    await oracleKeydonixWrappedToUnderlying.setUnderlying(context.collateral.address, poolAddress)

    const oracleKeydonixMainAsset = await deployContract('KeydonixOracleMainAsset_Mock', uniswapFactory.address, context.weth.address, context.chainLinkEthUsdAggregator.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_KEYDONIX_MAIN_ASSET, oracleKeydonixMainAsset.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateralUnderlying.address, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_MAIN_ASSET);

    const oracleKeydonixPoolToken = await deployContract('KeydonixOraclePoolToken_Mock', oracleKeydonixMainAsset.address);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_KEYDONIX_POOL_TOKEN, oracleKeydonixPoolToken.address);
    await context.oracleRegistry.setOracleTypeForAsset(poolAddress, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_POOL_TOKEN);

    await context.oracleRegistry.setKeydonixOracleTypes([
        ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING,
        ORACLE_TYPE_UNISWAP_V2_KEYDONIX_MAIN_ASSET,
        ORACLE_TYPE_UNISWAP_V2_KEYDONIX_POOL_TOKEN,
    ]);
}

async function prepareUniswapV2Pool(context) {
    context.chainLinkEthUsdAggregator = await deployContract("ChainlinkAggregator_Mock", 5e7, 8); // rewrite ethusd aggregator for price = 0.5/eth
    context.chainlinkOracleMainAsset.setAggregators(
        [context.weth.address],
        [context.chainLinkEthUsdAggregator.address],
        [], [],
    )

    const deployResult = await context.deployer.sendTransaction({
        data: UniswapV2FactoryDeployCode
    });

    const uniswapFactory = await attachContract("IUniswapV2Factory", deployResult.creates)
    const uniswapRouter = await deployContract('UniswapV2Router02', uniswapFactory.address, context.weth.address)

    await context.weth.deposit({value: ether('1')});
    await context.weth.approve(uniswapRouter.address, ether('100'));

    await poolDeposit(context, uniswapRouter, context.collateralUnderlying, 1);

    return [
        uniswapFactory,
        await uniswapFactory.getPair(context.weth.address, context.collateralUnderlying.address),
    ]
}

async function poolDeposit(context, uniswapRouter, token, collateralAmount) {
    collateralAmount = ether(collateralAmount.toString());
    const ethAmount = ether('1');
    await token.approve(uniswapRouter.address, collateralAmount);
    await uniswapRouter.addLiquidity(
        token.address,
        context.weth.address,
        collateralAmount,
        ethAmount,
        collateralAmount,
        ethAmount,
        context.deployer.address,
        1e18.toString(), // deadline
    );
}

module.exports = {
    prepareCoreContracts,
    prepareWrappedSSLP,

    SHIBA_TOPDOG_BONES_PER_BLOCK,
    SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT,

    CASE_WRAPPED_TO_UNDERLYING_SIMPLE,
    CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN,
    CASE_KEYDONIX_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN,
}
