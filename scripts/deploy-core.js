
const {createDeployment} = require('../lib/deployments/core');
const {runDeployment} = require('../test/helpers/deployUtils');


async function main() {
    const deployer = (await ethers.getSigners())[0].address;
    const deployment = await createDeployment({
        deployer,
        foundation: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        manager: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        wtoken: '0x5FbDB2315678afecb367f032d93F642f64180aa3'
    });

    const deployed = await runDeployment(deployment, {deployer});

    console.log(deployed);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
