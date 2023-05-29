const {ethers} = require("ethers");
const {SUSHI_MASTERCHEF_SUSHI_PER_BLOCK} = require("../../helpers/deploy");
const {BN} = require("../../helpers/ethersUtils");

function sushiReward(startBlock, endBlock) {
    return SUSHI_MASTERCHEF_SUSHI_PER_BLOCK
        .mul(endBlock-startBlock)
        .div(2) // 2 pools, divided between them
        ;
}

module.exports = {
    sushiReward,
}