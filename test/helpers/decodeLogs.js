const SolidityEvent = require('web3');

function decodeLogs (logs, contract, address) {
    return logs.map(log => {
        const event = new SolidityEvent(null, contract.events[log.topics[0]], address);
        return event.decode(log);
    });
}

module.exports = {
    decodeLogs,
};