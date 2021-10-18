const RLP = require('rlp');
const l = console.log;

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';


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


// --- Hardhat deployment script helpers --------------------------------------

async function _deploymentStep(name, args, options) {
    const {scope, signer, hre, verify, proxy} = options;
    const ethers = hre.ethers;

    const convertedArgs = [];
    for (const arg of args) {
        if (Array.isArray(arg) || typeof arg == 'boolean' || typeof arg == 'number' || ethers.utils.isAddress(arg)
                || (typeof arg == 'string' && arg.toLowerCase().startsWith('0x'))) {
            convertedArgs.push(arg);
        }
        else if (typeof arg == 'object' && 'addressAtNextNonce' in arg) {
            const nonce = await signer.getTransactionCount();
            convertedArgs.push("0x" + ethers.utils.keccak256(
                RLP.encode([signer.address, nonce + arg.addressAtNextNonce])
            ).slice(12).substring(14));
        }
        else {
            if (typeof arg != 'string')
                throw new Error('Bad arg type');
            if (!(arg in scope))
                throw new Error(`${arg} is not deployed yet, but was referenced by ${name}`);

            convertedArgs.push(scope[arg]);
        }
    }

    const dot = name.indexOf('.');
    if (-1 != dot) {
        // Transaction.
        if (proxy !== undefined)
            throw new Error(`Can't use proxy option for transaction: ${name}`);

        const fnName = name.substr(dot + 1);
        const contractName = name.substr(0, dot);
        if (!(contractName in scope))
            throw new Error(`${contractName} is not deployed yet, but was referenced by ${name}`);

        const contract = await ethers.getContractAt(contractName, scope[contractName], signer);
        const tx = await contract[fnName](...convertedArgs);
        const receipt = await tx.wait();
        if (1 != receipt.status)
            throw new Error(`${name} failed`);

        return;
    }

    // Contract deployment.
    if (name in scope)
        throw new Error(`${name} is already deployed`);

    const deployContract = async (name, args) => {
        const factory = await ethers.getContractFactory(name, signer);
        const contract = await factory.deploy(...args);
        await contract.deployed();

        if (verify) {
            await hre.run("verify:verify", {
                address: contract.address,
                constructorArguments: args,
            });
        }

        return contract.address;
    };

    let address = await deployContract(name, convertedArgs);
    if (proxy !== undefined) {
        address = await deployContract('UnitProxy', [address, proxy.admin, proxy.data || '0x']);
    }

    scope[name] = address;
}

/*
 * Runs a deployment script.
 * @param deployment - array containing deployment script
 * @param options.scope - some pre-deployed contract addresses, default to an empty one
 * @param options.deployer - account (address) to use to sign transactions, default to the first one
 * @param options.hre - hardhat runtime environment object, default to global variable `hre`
 * @param options.verify - bool, verify the contracts on *scan block explorers
 * @returns updated scope object
 */
async function runDeployment(deployment, options)
{
    let {scope, deployer: signer, hre, verify} = options;

    if (hre === undefined) {
        if (!('hre' in global))
            throw new Error('hardhat runtime environment is required');

        hre = global.hre;
    }

    if (signer === undefined)
        signer = (await hre.ethers.getSigners())[0];
    else
        signer = await hre.ethers.getSigner(signer);

    if (scope === undefined)
        scope = {};

    for (const step of deployment) {
        const stepOptions = (typeof step[0] == 'object') ? step.shift() : {};
        await _deploymentStep(step[0], step.slice(1), {scope, signer, hre, verify, ...stepOptions});
    }

    return scope;
}

// --- / Hardhat deployment script helpers ------------------------------------


module.exports = {
	buildDeployFn,
	estimateDeploymentGas,
	calculateAddressAtNonce,
	deployContractBytecode,
	runDeployment,
	ZERO_ADDRESS,
};
