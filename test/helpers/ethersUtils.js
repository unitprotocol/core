const {ethers} = require("hardhat");

async function attachContract(contract, address) {
    return ethers.getContractAt(contract, address)
}

async function deployContract(contract, ...args) {
    const ContractFactory = await ethers.getContractFactory(contract);
    return ContractFactory.deploy(...args);
}

module.exports = {
    attachContract,
    deployContract,
}
