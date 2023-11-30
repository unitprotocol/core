require("dotenv").config({ path: require("find-config")(".env") });
const { types } = require("hardhat/config")
const {createDeployment: createCoreDeployment} = require("./lib/deployments/core");
const {createDeployment: createWrappedSSLPDeployment} = require("./lib/deployments/wrappedSSLP");
const {createDeployment: createSwappersDeployment} = require("./lib/deployments/swappers");
const {runDeployment} = require("./test/helpers/deployUtils");
const {VAULT_PARAMETERS} = require("./network_constants");

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-local-networks-config-plugin");
require("@nomiclabs/hardhat-truffle5");
require("hardhat-gas-reporter");


task('deploy', 'Runs a core deployment')
    .addParam('foundation', 'Address of a foundation account/contract')
    .addParam('manager', 'Address of a manager account/contract')
    .addParam('wtoken', 'Address of a wrapped network token (e.g. WETH for Ethereum)')
    .addParam('baseBorrowFeePercent', 'Base borrow fee basis points (1pb=0.01%=0.0001, ie value must be 150 for 1.5%)', 150, types.int)
    .addParam('borrowFeeReceiver', 'Address of borrow fee receiver')
    .addOptionalParam('deployer', 'Address of a deployer account to use (defaults to the first account)')
    .addOptionalParam('noVerify', 'Skip contracts verification on *scan block explorer', false, types.boolean)
    .setAction(async (taskArgs) => {
        await hre.run("compile");

        const deployer = taskArgs.deployer ? taskArgs.deployer : (await ethers.getSigners())[0].address;
        const deployment = await createCoreDeployment({
            deployer,
            foundation: taskArgs.foundation,
            manager: taskArgs.manager,
            wtoken: taskArgs.wtoken,
            baseBorrowFeePercent: taskArgs.baseBorrowFeePercent,
            borrowFeeReceiver: taskArgs.borrowFeeReceiver,
            withHelpers: true,
        });

        const deployed = await runDeployment(deployment, {deployer, verify: !taskArgs.noVerify});

        console.log('Success!', deployed);
    });

task('deployWrappedSslp', 'Deploy wrapped sslp')
    .addParam('manager', 'Address of a manager account/contract')
    .addParam('topDogPoolId', 'id of pool in TopDog (each pool is for concrete sslp)', 0, types.int)
    .addParam('feeReceiver', 'Address of fee receiver')
    .addOptionalParam('topDog', 'Address of topDog', '0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7', types.string)
    .addOptionalParam('noVerify', 'Skip contracts verification on *scan block explorer', false, types.boolean)
    .setAction(async (taskArgs) => {
        await hre.run("compile");

        const deployer = taskArgs.deployer ? taskArgs.deployer : (await ethers.getSigners())[0].address;
        const deployment = await createWrappedSSLPDeployment({
            deployer,
            manager: taskArgs.manager,
            vaultParameters: VAULT_PARAMETERS,
            topDog: taskArgs.topDog,
            topDogPoolId: taskArgs.topDogPoolId,
            feeReceiver: taskArgs.feeReceiver,
        });

        const deployed = await runDeployment(deployment, {deployer, verify: !taskArgs.noVerify});

        console.log('Success!', deployed);
    });

task('deploySwappers', 'Deploy swappers')
    .addOptionalParam('noVerify', 'Skip contracts verification on *scan block explorer', false, types.boolean)
    .setAction(async (taskArgs) => {
        await hre.run("compile");

        const deployer = taskArgs.deployer ? taskArgs.deployer : (await ethers.getSigners())[0].address;
        const deployment = await createSwappersDeployment({
            deployer,
        });

        const deployed = await runDeployment(deployment, {deployer, verify: !taskArgs.noVerify});

        console.log('Success!', deployed);
    });

task('accounts', 'Show current accounts')
    .setAction(async (taskArgs) => {
        const signers = await ethers.getSigners();
        for (const acc of signers)
            console.log(acc.address, Number((await acc.getBalance()).toBigInt()) / 1e18);
    });


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    // Configure your network credentials at ~/.hardhat/networks.json,
    // see https://hardhat.org/plugins/hardhat-local-networks-config-plugin.html#usage
    //
    // E.g.:
    // {
    //     "networks": {
    //         "fantom-testnet": {
    //             "url": "https://rpc.testnet.fantom.network/",
    //             "accounts": [ ... ],
    //             "timeout": 180000
    //         },
    //     }
    // }

    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },

    gasReporter: {
        enabled: !process.env.NO_COVERAGE,
        currency: 'USD',
        gasPrice: 90
    },

    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: process.env.ETHERSCAN_API_KEY
    },

    mocha: {
        timeout: 180000, // requests to fork network could be slow
    },

    docgen: {
        outputDir: 'doc/dev-full',
        pages: 'items',
        exclude: ['interfaces', 'test-helpers', 'wrapped-assets/test-helpers'],
    },
};
