const {ORACLE_TYPE_CHAINLINK_MAIN_ASSET, ORACLE_TYPE_WRAPPED_TO_UNDERLYING} = require("../constants");

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

        ['VaultManagerParameters', 'VaultParameters'],
        ['VaultManagerBorrowFeeParameters', 'VaultParameters', baseBorrowFeePercent, borrowFeeReceiver],
        ['CDPManager01', 'VaultManagerParameters', 'OracleRegistry', 'CDPRegistry', 'VaultManagerBorrowFeeParameters'],
        ['ForceTransferAssetStore', 'VaultParameters', []],
        ['ForceMovePositionAssetStore', 'VaultParameters', []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'ForceTransferAssetStore', 'ForceMovePositionAssetStore'],

        // Vault access
        ['VaultParameters.setManager', 'VaultManagerParameters', true],
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
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
