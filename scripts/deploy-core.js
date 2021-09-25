
const {runDeployment, ZERO_ADDRESS} = require('../test/helpers/deployUtils');


const FOUNDATION = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const MSIG = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const WTOKEN = '0x5FbDB2315678afecb367f032d93F642f64180aa3';  // wrapped network token


async function main() {
    const deployer = (await ethers.getSigners())[0];

    const deployed = await runDeployment([
        // Core
        ['USDP', {addressAtNextNonce: +1}],
        ['VaultParameters', {addressAtNextNonce: +1}, FOUNDATION],
        ['Vault', 'VaultParameters', ZERO_ADDRESS, 'USDP', WTOKEN],

        ['CollateralRegistry', 'VaultParameters', []],
        ['CDPRegistry', 'Vault', 'CollateralRegistry'],
        ['OracleRegistry', 'VaultParameters', WTOKEN],

        ['VaultManagerParameters', 'VaultParameters'],
        ['CDPManager01', 'VaultManagerParameters', 'OracleRegistry', 'CDPRegistry'],
        ['ForceTransferAssetStore', 'VaultParameters', []],
        ['LiquidationAuction02', 'VaultManagerParameters', 'CDPRegistry', 'ForceTransferAssetStore'],

        ['ParametersBatchUpdater', 'VaultManagerParameters', 'OracleRegistry', 'CollateralRegistry'],

        // Vault access
        ['VaultParameters.setVaultAccess', 'CDPManager01', true],
        ['VaultParameters.setVaultAccess', 'LiquidationAuction02', true],

        // Oracles
        ['ChainlinkedOracleMainAsset', [], [], [], [], WTOKEN, 'VaultParameters'],

        // Manager access
        ['VaultParameters.setManager', MSIG, true],
        ['VaultParameters.setManager', deployer.address, false],
    ], undefined, deployer);

    console.log(deployed);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
