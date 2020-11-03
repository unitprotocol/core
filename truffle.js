require("dotenv").config({ path: require("find-config")(".env") });
const HDWalletProvider = require("truffle-hdwallet-provider");
const PrivateKeyProvider = require("truffle-privatekey-provider");

const getWalletProvider = function(network) {
	if (process.env.INFURA_PROJECT_ID == "") {
		console.log(process.env);
		console.error(">>>> ERROR: INFURA_PROJECT_ID is missing !!!");
		return;
	}

	const infuraAPI = "https://:"  + process.env.INFURA_PROJECT_SECRET + "@" + network + ".infura.io/v3/" + process.env.INFURA_PROJECT_ID;

	let provider;
	if (process.env.WALLET_PRIVATE_KEY != "") {
		provider = new PrivateKeyProvider(
			process.env.WALLET_PRIVATE_KEY,
			infuraAPI
		);
	} else if (process.env.WALLET_MNEMONIC != "") {
		provider = new HDWalletProvider(process.env.WALLET_MNEMONIC, infuraAPI);
	} else {
		console.log(process.env);
		console.error(
			">>>> ERROR: WALLET_PRIVATE_KEY or WALLET_MNEMONIC has to be set !!!"
		);
		return;
	}
	return provider;
};

module.exports = {
	networks: {
		coverage: {
			host: 'localhost',
			network_id: '*',
			port: 8555,
			gas: 0x6691b7,
			gasPrice: 0x01
		},
		ropsten: {
			network_id: "3",
			provider: function() {
				return getWalletProvider("ropsten");
			},
			gasPrice: 1000000000,
			gas: 6700000
		},
		rinkeby: {
			network_id: "4",
			provider: function() {
				return getWalletProvider("rinkeby");
			},
			gasPrice: 1000000000,
			gas: 6700000
		},
		kovan: {
			network_id: "42",
			provider: function() {
				return getWalletProvider("kovan");
			},
			gasPrice: 1000000000,
			gas: 6700000
		},
	},
	mocha: {
		reporter: 'eth-gas-reporter',
		reporterOptions: {
			currency: 'USD',
			currency: 'eth-gas-reporter',
			gasPrice: 90
		}
	},
	solc: {
		optimizer: {
			enabled: true,
			runs: 200
		}
	},
	plugins: ["solidity-coverage"],
	compilers: {
		solc: {
			version: '0.7.4'
		}
	}
};
