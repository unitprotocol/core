const {createDeployment: createCoreDeployment} = require("../../lib/deployments/core");
const {runDeployment, loadHRE} = require("../helpers/deployUtils");
const {ethers} = require("hardhat");
const {attachContract, deployContract, Q112} = require("./ethersUtils");
const {ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING,
    ORACLE_TYPE_BRIDGED_USDP, ORACLE_TYPE_MOCK, ORACLE_TYPE_KEYDONIX_MOCK,
} = require("../../lib/constants");

const EthersBN = ethers.BigNumber.from;
const ether = ethers.utils.parseUnits;

const BORROW_FEE_RECEIVER_ADDRESS = '0x0000000000000000000000000000000123456789';

const CASE_ORACLE_MOCK = 9999;
const CASE_ORACLE_KEYDONIX_MOCK = 9998;
const CASE_WRAPPED_TO_UNDERLYING_CHAINLINK = 1;
const CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN = 2;
const CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX = 3;
const CASE_CHAINLINK = 4;
const CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX = 5;
const CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX = 6;
const CASE_BRIDGED_USDP = 7;

const PREPARE_ORACLES_METHODS = {
    [CASE_ORACLE_MOCK]: prepareOracleMock,
    [CASE_ORACLE_KEYDONIX_MOCK]: prepareOracleKeydonixMock,
    [CASE_WRAPPED_TO_UNDERLYING_CHAINLINK]: prepareWrappedToUnderlyingOracle,
    [CASE_CHAINLINK]: prepareChainlinkOracle,
    [CASE_BRIDGED_USDP]: prepareBridgedUsdpOracle,
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
 * - oracle - oracle contract
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
    context.vault = (await attachContract("Vault", deployedAddresses.Vault)).connect((await ethers.getSigners())[1]); // TransparentUpgradeableProxy: admin cannot fallback to proxy target
    context.oracleRegistry = await attachContract("OracleRegistry", deployedAddresses.OracleRegistry);
    context.assetsBooleanParameters = await attachContract("AssetsBooleanParameters", deployedAddresses.AssetsBooleanParameters);
    context.chainlinkOracleMainAsset = await attachContract("ChainlinkedOracleMainAsset", deployedAddresses.ChainlinkedOracleMainAsset);
    context.wrappedToUnderlyingOracle = await attachContract("WrappedToUnderlyingOracle", deployedAddresses.WrappedToUnderlyingOracle);
    context.vaultManagerParameters = await attachContract("VaultManagerParameters", deployedAddresses.VaultManagerParameters);
    context.liquidationAuction = await attachContract("LiquidationAuction02", deployedAddresses.LiquidationAuction02);

    context.cdpManager = await attachContract("CDPManager01", deployedAddresses.CDPManager01);

    // only in stable/ethereum fallback is deployed. Still test it everywhere
    context.cdpManagerKeydonix = await deployContract("CDPManager01_Fallback",
        deployedAddresses.VaultManagerParameters, deployedAddresses.OracleRegistry,
        deployedAddresses.CDPRegistry, deployedAddresses.VaultManagerBorrowFeeParameters
    );
    await context.vaultParameters.setVaultAccess(context.cdpManagerKeydonix.address, true);

    context.chainLinkEthUsdAggregator = await deployContract("ChainlinkAggregator_Mock", 250e8, 8); // 250usd/eth
    await context.oracleRegistry.setOracleTypeForAsset(context.weth.address, ORACLE_TYPE_CHAINLINK_MAIN_ASSET);
    context.chainlinkOracleMainAsset.setAggregators(
        [context.weth.address],
        [context.chainLinkEthUsdAggregator.address],
        [], [],
    )

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
        );
    }
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

async function prepareOracleMock(context, {collateral}) {
    context.collateral = collateral ?? await deployContract("DummyToken", "Token", "TKN", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_MOCK;

    context.oracle = await deployContract('SimpleOracleMock');
    await context.oracleRegistry.setOracle(ORACLE_TYPE_MOCK, context.oracle.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, context.collateralOracleType);
}

async function prepareOracleKeydonixMock(context, {collateral}) {
    context.collateral = collateral ?? await deployContract("DummyToken", "Token", "TKN", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_KEYDONIX_MOCK;

    context.oracle = await deployContract('SimpleOracleKeydonixMock');
    await context.oracleRegistry.setOracle(ORACLE_TYPE_KEYDONIX_MOCK, context.oracle.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, context.collateralOracleType);

    await context.oracleRegistry.setKeydonixOracleTypes([
        ORACLE_TYPE_KEYDONIX_MOCK,
    ]);
}


async function prepareWrappedToUnderlyingOracle(context, {collateral}) {
    // todo check if curveLpOracle exist as additional oracle case (see WrappedToUnderlyingOracle section in utils)

    // wrapped token
    context.collateral = collateral ?? await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_WRAPPED_TO_UNDERLYING;
    context.oracle = context.wrappedToUnderlyingOracle

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

async function prepareChainlinkOracle(context, {collateral}) {
    context.collateral = collateral ?? await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_CHAINLINK_MAIN_ASSET;

    context.oracle = context.chainlinkOracleMainAsset

    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, context.collateralOracleType);

    if (context.collateral !== context.weth) { // for weth we already have set aggregator
        const chainlinkAggregator = await deployContract("ChainlinkAggregator_Mock", 500e8.toString(), 8);
        await context.chainlinkOracleMainAsset.setAggregators(
            [context.collateral.address], [chainlinkAggregator.address],
            [], []
        );
    }
}

async function prepareBridgedUsdpOracle(context) {
    context.collateral = await deployContract("DummyToken", "Wrapper token", "wtoken", 18, ether('100000000000'));
    context.collateralOracleType = ORACLE_TYPE_BRIDGED_USDP;

    context.oracle = await deployContract('BridgedUsdpOracle', context.vaultParameters.address, [context.collateral.address]);
    await context.oracleRegistry.setOracle(ORACLE_TYPE_BRIDGED_USDP, context.oracle.address);
    await context.oracleRegistry.setOracleTypeForAsset(context.collateral.address, ORACLE_TYPE_BRIDGED_USDP);
}

module.exports = {
    prepareCoreContracts,

    CASE_ORACLE_MOCK,
    CASE_ORACLE_KEYDONIX_MOCK,
    CASE_WRAPPED_TO_UNDERLYING_CHAINLINK,
    CASE_CHAINLINK,
    CASE_BRIDGED_USDP,
}
