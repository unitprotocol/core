
const {ZERO_ADDRESS} = require('../../test/helpers/deployUtils');


// args:
// deployer - deploy using this address
// foundation - foundation address
// manager - VaultParameters manager address
// wtoken - wrapped network token address (e.g. WETH for Ethereum)
const createDeployment = async function(args) {
    const {deployer, foundation, manager, wtoken} = args;

    const script = [
        // Core
        ['USDP', {addressAtNextNonce: +1}],
        ['VaultParameters', {addressAtNextNonce: +1}, foundation],
        ['Vault', 'VaultParameters', ZERO_ADDRESS, 'USDP', wtoken],

        ['CollateralRegistry', 'VaultParameters', []],
        ['CDPRegistry', 'Vault', 'CollateralRegistry'],
        ['OracleRegistry', 'VaultParameters', wtoken],

        ['VaultManagerParameters', 'VaultParameters'],
        ['CDPManager01', 'VaultManagerParameters', 'OracleRegistry', 'CDPRegistry'],
        ['ForceTransferAssetStore', 'VaultParameters', []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'ForceTransferAssetStore'],

        ['ParametersBatchUpdater', 'VaultManagerParameters', 'OracleRegistry', 'CollateralRegistry'],

        // Vault access
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
        ['VaultParameters.setVaultAccess', 'LiquidationAuction02', true],

        // Oracles
        ['ChainlinkedOracleMainAsset', [], [], [], [], wtoken, 'VaultParameters'],
    ];

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
