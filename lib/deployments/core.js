const {
    ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING, ORACLE_TYPE_BRIDGED_USDP,
} = require("../constants");

// args:
// deployer - deploy using this address
// foundation - foundation address
// manager - VaultParameters manager address
// wtoken - wrapped network token address (e.g. WETH for Ethereum)
// withHelpers - bool, also deploy various non-core helpers
const createDeployment = async function(args) {
    const {deployer, foundation, manager, wtoken, baseBorrowFeePercent, borrowFeeReceiver, withHelpers, testEnvironment=false} = args;

    const USDP = testEnvironment ? 'USDPMock' : 'USDP';
    const script = [
        // Core
        [USDP, {addressAtNextNonce: +1}, "str:USDP Stablecoin", "str:USDP"],
        ['VaultParameters', {addressAtNextNonce: +2}, foundation],
        [{proxy: {admin: manager}}, 'Vault', 'VaultParameters', USDP, wtoken],
        [`${USDP}.setMinter`, 'Vault', true],

        ['CollateralRegistry', 'VaultParameters', []],
        ['CDPRegistry', 'Vault', 'CollateralRegistry'],
        ['OracleRegistry', 'VaultParameters', wtoken],

        ['VaultManagerParameters', 'VaultParameters'],
        ['VaultManagerBorrowFeeParameters', 'VaultParameters', baseBorrowFeePercent, borrowFeeReceiver],
        ['CDPManager01', 'VaultManagerParameters', 'OracleRegistry', 'CDPRegistry', 'VaultManagerBorrowFeeParameters'],
        ['AssetsBooleanParameters', 'VaultParameters', [], []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'AssetsBooleanParameters'],

        // Vault access
        ['VaultParameters.setManager', 'VaultManagerParameters', true],
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
        ['VaultParameters.setVaultAccess', 'LiquidationAuction02', true],

        // Oracles
        ['WrappedToUnderlyingOracle', 'VaultParameters', 'OracleRegistry'],
        ['ChainlinkedOracleMainAsset', [], [], [], [], wtoken, 'VaultParameters'],
        ['BridgedUsdpOracle', 'VaultParameters', []],
        ['OracleRegistry.setOracle', ORACLE_TYPE_CHAINLINK_MAIN_ASSET, 'ChainlinkedOracleMainAsset'],
        ['OracleRegistry.setOracle', ORACLE_TYPE_WRAPPED_TO_UNDERLYING, 'WrappedToUnderlyingOracle'],
        ['OracleRegistry.setOracle', ORACLE_TYPE_BRIDGED_USDP, 'BridgedUsdpOracle'],
    ];

    // Helpers
    if (withHelpers)
        script.push(
            ['ParametersBatchUpdater', 'VaultManagerParameters', 'OracleRegistry', 'CollateralRegistry'],
            ['VaultParameters.setManager', 'ParametersBatchUpdater', true],
            ['AssetParametersViewer', 'VaultManagerParameters', 'VaultManagerBorrowFeeParameters', 'AssetsBooleanParameters'],
            ['CDPViewer', 'VaultManagerParameters', 'OracleRegistry', 'VaultManagerBorrowFeeParameters'],
        );

    // Manager access
    if (manager.toLowerCase() != deployer.toLowerCase())
        script.push(
            ['VaultParameters.setManager', manager, true],
            ['VaultParameters.setManager', deployer, false]
        );

    return script;
};


module.exports = {
	createDeployment,
};
