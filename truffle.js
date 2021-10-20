require("dotenv").config({ path: require("find-config")(".env") });
const HDWalletProvider = require("truffle-hdwallet-provider");
const PrivateKeyProvider = require("truffle-privatekey-provider");
const Web3HttpProvider = require('web3-providers-http');
const NewHDWalletProvider = require("@truffle/hdwallet-provider");

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

const FANTOM_KEYS = [process.env.FANTOM_WALLET_PRIVATE_KEY, process.env.FANTOM_WALLET_PRIVATE_KEY2,
    process.env.FANTOM_WALLET_PRIVATE_KEY3, process.env.FANTOM_WALLET_PRIVATE_KEY4];


module.exports = {
	networks: {
		coverage: {
			host: 'localhost',
			network_id: '*',
			port: 8555,
			gas: 0x6691b7,
			gasPrice: 0x01
		},
		localhost: {
			host: 'localhost',
			network_id: '*',
			port: 8545,
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
		fantom: {
			network_id: "250",
		    provider: function() {
		        return new NewHDWalletProvider({
                    privateKeys: FANTOM_KEYS,
                    providerOrUrl: new Web3HttpProvider(process.env.FANTOM_NODE_URL, {timeout: 1800000}),
                });
            }
		},
		'fantom-testnet': {
			network_id: "4002",
		    provider: function() {
		        return new NewHDWalletProvider({
                    privateKeys: FANTOM_KEYS,
                    providerOrUrl: new Web3HttpProvider('https://rpc.testnet.fantom.network/', {timeout: 180000}),
                });
            }
		},
		'fantom-local': {
			network_id: "4003",
		    provider: function() {
		        return new NewHDWalletProvider({
                    privateKeys: FANTOM_KEYS,
                    providerOrUrl: new Web3HttpProvider('http://localhost:4000', {timeout: 30000}),
                });
            }
		},
	},
	mocha: process.env.NO_COVERAGE ? {} : {
		reporter: 'eth-gas-reporter',
		reporterOptions: {
			currency: 'USD',
			gasPrice: 90
		}
	},
	solc: {
		optimizer: {
			enabled: true,
			runs: 200
		}
	},
	plugins: process.env.NO_COVERAGE ? [] : ["solidity-coverage"],
	compilers: {
		solc: {
			version: '0.7.6'
		}
	}
};
