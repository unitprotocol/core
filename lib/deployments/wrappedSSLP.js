const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, topDog, topDogPoolId} = args;

    const script = [
        ['WrappedShibaSwapLp', vaultParameters, topDog, topDogPoolId],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
