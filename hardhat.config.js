require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");


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
