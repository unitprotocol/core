require("dotenv").config({ path: require("find-config")(".env") });
const { types } = require("hardhat/config")

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-local-networks-config-plugin");


task('deploy', 'Runs a core deployment')
    .addParam('foundation', 'Address of a foundation account/contract')
    .addParam('manager', 'Address of a manager account/contract')
    .addParam('wtoken', 'Address of a wrapped network token (e.g. WETH for Ethereum)')
    .addOptionalParam('deployer', 'Address of a deployer account to use (defaults to the first account)')
    .addOptionalParam('noVerify', 'Skip contracts verification on *scan block explorer', false, types.boolean)
    .setAction(async (taskArgs) => {
        await hre.run("compile");

        const {createDeployment} = require('./lib/deployments/core');
        const {runDeployment} = require('./test/helpers/deployUtils');

        const deployer = taskArgs.deployer ? taskArgs.deployer : (await ethers.getSigners())[0].address;
        const deployment = await createDeployment({
            deployer,
            foundation: taskArgs.foundation,
            manager: taskArgs.manager,
            wtoken: taskArgs.wtoken,
            withHelpers: true,
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

    mocha: process.env.NO_COVERAGE ? {} : {
        reporter: 'eth-gas-reporter',
        reporterOptions: {
            currency: 'USD',
            gasPrice: 90
        }
    },

    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: process.env.ETHERSCAN_API_KEY
    }
};
