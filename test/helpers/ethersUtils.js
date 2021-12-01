const {ethers} = require("hardhat");

async function attachContract(contract, address) {
    const ContractFactory = await ethers.getContractFactory(contract);
    return ContractFactory.attach(address);
}

async function deployContract(contract, ...args) {
    const ContractFactory = await ethers.getContractFactory(contract);
    return ContractFactory.deploy(...args);
}

module.exports = {
    attachContract,
    deployContract,
}
