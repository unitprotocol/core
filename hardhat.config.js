require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");


task('deploy', 'Runs a core deployment')
    .addParam('foundation', 'Address of a foundation account/contract')
    .addParam('manager', 'Address of a manager account/contract')
    .addParam('wtoken', 'Address of a wrapped network token (e.g. WETH for Ethereum)')
    .addOptionalParam('deployer', 'Address of a deployer account to use (defaults to the first account)')
    .setAction(async (taskArgs) => {
        const {createDeployment} = require('./lib/deployments/core');
        const {runDeployment} = require('./test/helpers/deployUtils');

        const deployer = taskArgs.deployer ? taskArgs.deployer : (await ethers.getSigners())[0].address;
        const deployment = await createDeployment({
            deployer,
            foundation: taskArgs.foundation,
            manager: taskArgs.manager,
            wtoken: taskArgs.wtoken
        });

        const deployed = await runDeployment(deployment, {deployer});

        console.log('Success!', deployed);
    });


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },

	mocha: {
		reporter: 'eth-gas-reporter',
		reporterOptions: {
			currency: 'USD',
			gasPrice: 90
		}
	},
};
