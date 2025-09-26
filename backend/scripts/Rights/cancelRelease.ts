import hre, { ethers, deployments, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../utils/confirmAction';

/// Cancels a release, burning all shares batched
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

    const gildiManagerBalance = await ethers.provider.getBalance(gildiManager);
    console.log(`GildiManager balance: ${ethers.formatEther(gildiManagerBalance)} BASE COIN`);

    const gildiManagerSigner = await ethers.getSigner(gildiManager);
    const gildiManagerContract = await ethers.getContractAt('GildiManager', gildiManagerDeployment.address, gildiManagerSigner);

    if (!await gildiManagerContract.releaseExists(RELEASE_ID)) {
        throw new Error('Release does not exist, cannot cancel');
    }

    const release = await gildiManagerContract.rwaReleases(RELEASE_ID);
    if (!release.locked) {
        throw new Error('Release is unlocked, cannot cancel');
    }
    if (release.inInitialSale) {
        throw new Error('Release is in initial sale, cannot cancel');
    }

    const confirmed = await confirmActionAsync(`Cancel release ${RELEASE_ID}?`, false);
    if (!confirmed) {
        throw new Error('User cancelled');
    }

    const batchSize = 100;
    while (await gildiManagerContract.releaseExists(RELEASE_ID)) {
        console.log(`Deleting recipients from release ${RELEASE_ID} in batches of ${batchSize}...`);
        await gildiManagerContract.batchDeleteRelease(RELEASE_ID, batchSize);
        console.log(`Deleted recipients from release ${RELEASE_ID}`);

        let sharesRemaining = 0n;
        if (await gildiManagerContract.releaseExists(RELEASE_ID)) {
            const release = await gildiManagerContract.rwaReleases(RELEASE_ID);
            sharesRemaining = release.totalShares - release.deletedShares;
        }
        console.log(`Shares remaining in release ${RELEASE_ID}: ${sharesRemaining.toString()}`);
    }

    console.log(`Cancelled release ${RELEASE_ID}`);
}

main().then(() => process.exit(0)).catch(error => {
    console.error(error);
    process.exit(1);
});