// Sushi
const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, rewardDistributor, feeReceiver, feePercent} = args;

    const script = [
        ['WSLPFactory', vaultParameters, rewardDistributor, feeReceiver, feePercent],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
