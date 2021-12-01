const createDeployment = async function(args) {
    const {deployer, manager, vaultParameters, boneToken, topDog, topDogPoolId} = args;

    const script = [
        [{proxy: {admin: manager}}, 'WrappedShibaSwapLp', vaultParameters, boneToken, topDog, topDogPoolId],
        ['WrappedShibaSwapLp.init'],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
