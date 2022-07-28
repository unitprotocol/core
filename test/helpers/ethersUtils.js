const {ethers, network} = require("hardhat");

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

async function getBlockTs(blockNumber) {
    return (await ethers.provider.getBlock(blockNumber)).timestamp
}

async function increaseTime(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}


const ether = ethers.utils.parseEther;
const weiToEther = wei => ethers.utils.formatUnits(wei, "ether");
const BN = ethers.BigNumber.from
const Q112 = BN('2').pow(BN('112'));

module.exports = {
    attachContract,
    deployContract,
    getRandomSigner,
    getBlockTs,
    increaseTime,

    ether,
    weiToEther,
    BN,
    Q112
}
