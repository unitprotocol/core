const {ethers} = require("ethers");
const {SHIBA_TOPDOG_BONES_PER_BLOCK, SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT} = require("../../helpers/deploy");
const {BN} = require("../../helpers/ethersUtils");

function directBonesReward(startBlock, endBlock) {
    return SHIBA_TOPDOG_BONES_PER_BLOCK
        .mul(endBlock-startBlock)
        .mul(SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT).div(100)
        .div(2) // 2 pools, divided between them
        ;
}

function lockedBonesReward(startBlock, endBlock) {
    return SHIBA_TOPDOG_BONES_PER_BLOCK
        .mul(endBlock-startBlock)
        .mul(BN('100').sub(SHIBA_TOPDOG_DIRECT_BONES_USER_PERCENT)).div(100)
        .div(2) // 2 pools, divided between them
        ;
}

function fullBonesReward(startBlock, endBlock) {
    return SHIBA_TOPDOG_BONES_PER_BLOCK
        .mul(endBlock-startBlock)
        .div(2) // 2 pools, divided between them
        ;
}

module.exports = {
    directBonesReward,
    lockedBonesReward,
    fullBonesReward
}