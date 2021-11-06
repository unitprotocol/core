
// args:
// deployer - deploy using this address
// foundation - foundation address
// manager - VaultParameters manager address
// wtoken - wrapped network token address (e.g. WETH for Ethereum)
// withHelpers - bool, also deploy various non-core helpers
const createDeployment = async function(args) {
    const {deployer, foundation, manager, wtoken, withHelpers} = args;

    const script = [
        // Core
        ['USDP', {addressAtNextNonce: +1}],
        ['VaultParameters', {addressAtNextNonce: +2}, foundation],
        [{proxy: {admin: manager}}, 'Vault', 'VaultParameters', 'USDP', wtoken],
        ['USDP.setMinter', 'Vault', true],

        ['CollateralRegistry', 'VaultParameters', []],
        ['CDPRegistry', 'Vault', 'CollateralRegistry'],
        ['OracleRegistry', 'VaultParameters', wtoken],

        ['VaultManagerParameters', 'VaultParameters'],
        ['CDPManager01', 'VaultManagerParameters', 'OracleRegistry', 'CDPRegistry'],
        ['ForceTransferAssetStore', 'VaultParameters', []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'ForceTransferAssetStore', false],

        // Vault access
        ['VaultParameters.setManager', 'VaultManagerParameters', true],
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
        ['VaultParameters.setVaultAccess', 'LiquidationAuction02', true],

        // Oracles
        ['WrappedToUnderlyingOracle', 'VaultParameters', 'OracleRegistry'],
        ['ChainlinkedOracleMainAsset', [], [], [], [], wtoken, 'VaultParameters'],
        ['OracleRegistry.setOracle', 5, 'ChainlinkedOracleMainAsset'],
        ['OracleRegistry.setOracle', 11, 'WrappedToUnderlyingOracle'],
    ];

    // Helpers
    if (withHelpers)
        script.push(
            ['ParametersBatchUpdater', 'VaultManagerParameters', 'OracleRegistry', 'CollateralRegistry'],
            ['VaultParameters.setManager', 'ParametersBatchUpdater', true],
            ['AssetParametersViewer', 'VaultManagerParameters'],
            ['CDPViewer', 'VaultManagerParameters', 'OracleRegistry'],
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
