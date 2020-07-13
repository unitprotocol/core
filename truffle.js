module.exports = {
	networks: {
		coverage: {
			host: 'localhost',
			network_id: '*',
			port: 8555,
			gas: 0xfffffffffff,
			gasPrice: 0x01
		}
		// development: {
		// 	host: 'localhost',
		// 	port: 8545,
		// 	network_id: '*',
		// 	gas: 7669217,
		// 	gasPrice: 0x01
		// }
	},
	mocha: {
		// reporter: 'eth-gas-reporter',
		// reporterOptions: {
		// 	currency: 'USD',
		// 	gasPrice: 10
		// }
	},
	solc: {
		optimizer: {
			enabled: true,
			runs: 200
		}
	},
	plugins: ['truffle-security'],
	compilers: {
		solc: {
			version: '0.5.11' // ex:  "0.4.20". (Default: Truffle's installed solc)
		}
	}
};
