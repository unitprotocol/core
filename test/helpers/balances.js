const BN = web3.utils.BN;

async function balanceCurrent (account) {
    return new BN(await web3.eth.getBalance(account));
}

async function balanceDifference (account, promiseFunc) {
    const balanceBefore = new BN(await web3.eth.getBalance(account));
    await promiseFunc;
    const balanceAfter = new BN(await web3.eth.getBalance(account));

    return balanceAfter.gt(balanceBefore) ? balanceAfter.sub(balanceBefore) : balanceBefore.sub(balanceAfter);
}

async function differenceExcludeGas (account, promiseFunc, gasPrice) {
    const balanceBefore = new BN(await web3.eth.getBalance(account));
    let tx = await promiseFunc;
    let gas = new BN(tx.receipt.gasUsed).mul(gasPrice);
    const balanceAfter = new BN(await web3.eth.getBalance(account)).add(gas);
    return balanceAfter.gt(balanceBefore) ? balanceAfter.sub(balanceBefore) : balanceBefore.sub(balanceAfter);
}

module.exports = {
    current: balanceCurrent,
    difference: balanceDifference,
    differenceExcludeGas: differenceExcludeGas,
};
