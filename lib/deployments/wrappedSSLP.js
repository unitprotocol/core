const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, topDog, topDogPoolId, feeReceiver} = args;

    const script = [
        ['WrappedShibaSwapLp', vaultParameters, topDog, topDogPoolId, feeReceiver],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
