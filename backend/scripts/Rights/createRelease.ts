import hre, { ethers, deployments, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../utils/confirmAction';

async function main() {
    const NUM_SHARES = parseInt(process.env.NUM_SHARES ?? "0") || 0;
    const RELEASE_ID = parseInt(process.env.RELEASE_ID ?? "0") || 0;
    if (NUM_SHARES == 0) {
        throw new Error('Missing NUM_SHARES environment variable or invalid value');
    }
    if (RELEASE_ID == 0) {
        throw new Error('Missing RELEASE_ID environment variable or invalid value');
    }

    const { gildiManager } = await getNamedAccounts();
    if (!gildiManager) {
        throw new Error('Missing named account: gildiManager');
    }

    const gildiManagerDeployment = await deployments.getOrNull('GildiManager');
    if (!gildiManagerDeployment) {
        throw new Error('GildiManager deployment not found');
    }

    const gildiManagerSigner = await ethers.getSigner(gildiManager);
    const gildiManagerContract = await ethers.getContractAt('GildiManager', gildiManagerDeployment.address, gildiManagerSigner);

    if (await gildiManagerContract.releaseExists(RELEASE_ID)) {
        throw new Error('Release already exists, cannot create it again');
    }

    const confirmed = await confirmActionAsync(`Create release ${RELEASE_ID} with ${NUM_SHARES} shares?`, false);
    if (!confirmed) {
        throw new Error('User cancelled');
    }
    await gildiManagerContract.createNewRelease(RELEASE_ID, NUM_SHARES, 0);

    console.log(`Created release ${RELEASE_ID} with ${NUM_SHARES} shares`);
}

main().then(() => process.exit(0)).catch(error => {
    console.error(error);
    process.exit(1);
});