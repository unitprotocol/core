// Returns the time of the last mined block in seconds
async function latest () {
    const block = await web3.eth.getBlock('latest');
    return new web3.utils.BN(block.timestamp);
}
async function block () {
    const block = await web3.eth.getBlock('latest');
    return new web3.utils.BN(block.number);
}
async function blockNumberFromReceipt(receipt) {
    return new web3.utils.BN(receipt.receipt.blockNumber)
}
module.exports = {
    latest,
    block,
    blockNumberFromReceipt,
}
