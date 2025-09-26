import hre, { ethers, deployments, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../utils/confirmAction';

async function main() {
    const RELEASE_ID = parseInt(process.env.RELEASE_ID ?? "0") || 0;
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

    if (!await gildiManagerContract.releaseExists(RELEASE_ID)) {
        throw new Error('Release does not exist, cannot unlock');
    }

    const release = await gildiManagerContract.rwaReleases(RELEASE_ID);
    if (!release.locked) {
        throw new Error('Release is already unlocked');
    }

    const confirmed = await confirmActionAsync(`Unlock release ${RELEASE_ID}?`, false);
    if (!confirmed) {
        throw new Error('User cancelled');
    }

    await gildiManagerContract.unlockRelease(RELEASE_ID);

    console.log(`Unlocked release ${RELEASE_ID}`);
}

main().then(() => process.exit(0)).catch(error => {
    console.error(error);
    process.exit(1);
});