// Returns the time of the last mined block in seconds
async function latest () {
    const block = await web3.eth.getBlock('latest');
    return new web3.utils.BN(block.timestamp);
}
module.exports = {
    latest,
}
