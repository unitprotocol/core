const {
    ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING,
    PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION,
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
        [USDP, {addressAtNextNonce: +1}],
        ['VaultParameters', {addressAtNextNonce: +1}, foundation],
        ['Vault', 'VaultParameters', '0x0000000000000000000000000000000000000000', USDP, wtoken],

        ['CollateralRegistry', 'VaultParameters', []],
        ['CDPRegistry', 'Vault', 'CollateralRegistry'],
        ['OracleRegistry', 'VaultParameters', wtoken],
        ['SwappersRegistry', 'VaultParameters'],

        ['VaultManagerParameters', 'VaultParameters'],
        ['VaultManagerBorrowFeeParameters', 'VaultParameters', baseBorrowFeePercent, borrowFeeReceiver],
        ['CDPManager01', 'VaultManagerParameters', 'VaultManagerBorrowFeeParameters', 'OracleRegistry', 'CDPRegistry', 'SwappersRegistry'],
        ['CDPManager01_Fallback', 'VaultManagerParameters', 'VaultManagerBorrowFeeParameters', 'OracleRegistry', 'CDPRegistry', 'SwappersRegistry'],
        ['AssetsBooleanParameters', 'VaultParameters', [], []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'AssetsBooleanParameters'],

        // Vault access
        ['VaultParameters.setManager', 'VaultManagerParameters', true],
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
        ['VaultParameters.setVaultAccess', 'CDPManager01_Fallback', true],
        ['VaultParameters.setVaultAccess', 'LiquidationAuction02', true],

        // Oracles
        ['WrappedToUnderlyingOracle', 'VaultParameters', 'OracleRegistry'],
        ['ChainlinkedOracleMainAsset', [], [], [], [], wtoken, 'VaultParameters'],
        ['OracleRegistry.setOracle', ORACLE_TYPE_CHAINLINK_MAIN_ASSET, 'ChainlinkedOracleMainAsset'],
        ['OracleRegistry.setOracle', ORACLE_TYPE_WRAPPED_TO_UNDERLYING, 'WrappedToUnderlyingOracle'],
    ];

    // Helpers
    if (withHelpers)
        script.push(
            ['ParametersBatchUpdater', 'VaultManagerParameters', 'OracleRegistry', 'CollateralRegistry'],
            ['VaultParameters.setManager', 'ParametersBatchUpdater', true],
            ['AssetParametersViewer', 'VaultManagerParameters', 'VaultManagerBorrowFeeParameters'],
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
