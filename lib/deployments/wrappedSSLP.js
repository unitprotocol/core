const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, boneToken, topDog, topDogPoolId} = args;

    const script = [
        ['WrappedShibaSwapLp', vaultParameters, boneToken, topDog, topDogPoolId],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
