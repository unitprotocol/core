const RLP = require('rlp');

async function buildDeployFn(deployer, contract) {
	const gasPrice = Number(await contract.web3.eth.getGasPrice());
	return async (contractToDeploy, args = []) => {
		const gas = await estimateDeploymentGas(contractToDeploy, args);
		const instance = await deployer.deploy(contractToDeploy, ...args, { gas: gas + 100000, gasPrice });
		console.log(`${contractToDeploy._json.contractName}: ${contractToDeploy.address}`);
		return instance;
	};
}

async function deployContractBytecode(bytecode, deployer, web3) {
	const gasLimit = 7000000;
	const gasPrice = Number(await web3.eth.getGasPrice());

	const deployTx = {
		data: bytecode,
		gasPrice,
		gas: gasLimit,
		from: deployer,
		value: '0x00'
	};

	const gas = Number(await web3.eth.estimateGas(deployTx));

	deployTx.gas = gas;
	const res = await web3.eth.sendTransaction(deployTx);
	return res.contractAddress;
}

async function estimateDeploymentGas(truffleContract, args) {
	const web3Contract = new web3.eth.Contract(truffleContract._json.abi);
	const deployTx = web3Contract.deploy({
		data: truffleContract._json.bytecode,
		arguments: args
	});

	return await deployTx.estimateGas();
}

function calculateAddressAtNonce(sender, nonce, web3Inst = web3) {
	return "0x" + web3Inst.utils.sha3(RLP.encode([sender, nonce])).slice(12).substring(14);
}


module.exports = {
	buildDeployFn,
	estimateDeploymentGas,
	calculateAddressAtNonce,
	deployContractBytecode,
};
