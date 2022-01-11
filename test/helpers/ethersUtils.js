const {ethers} = require("hardhat");

async function attachContract(contract, address) {
    return ethers.getContractAt(contract, address)
}

async function deployContract(contract, ...args) {
    const ContractFactory = await ethers.getContractFactory(contract);
    const deployedContract = await ContractFactory.deploy(...args);
    await deployedContract.deployed();

    return deployedContract;
}

module.exports = {
    attachContract,
    deployContract,
}
