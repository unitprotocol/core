// Sushi
const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, rewardDistributor, rewardDistributorPoolId, feeReceiver} = args;

    const script = [
        ['WrappedSushiSwapLp', vaultParameters, rewardDistributor, rewardDistributorPoolId, feeReceiver],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
