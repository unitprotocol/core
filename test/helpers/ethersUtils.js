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

function getRandomSigner() {
    return new ethers.Wallet(ethers.Wallet.createRandom().privateKey, ethers.provider);
}

const ether = ethers.utils.parseEther;
const weiToEther = wei => ethers.utils.formatUnits(wei, "ether");
const BN = ethers.BigNumber.from
const Q112 = BN('2').pow(BN('112'));

module.exports = {
    attachContract,
    deployContract,
    getRandomSigner,

    ether,
    weiToEther,
    BN,
    Q112
}
