import hre, { ethers, deployments, getNamedAccounts } from 'hardhat';
import fs from 'fs-extra';
import Papa from 'papaparse';
import { IGildiManager } from '../../typechain-types';
import { confirmActionAsync } from '../../utils/confirmAction';

async function main() {
    const RELEASE_ID = process.env.RELEASE_ID ? parseInt(process.env.RELEASE_ID) : 0;
    if (RELEASE_ID == 0 || isNaN(RELEASE_ID)) {
        throw new Error('Missing RELEASE_ID environment variable or invalid value');
    }

    // Receivers and Amounts are comma separated environment variables, receivers must be valid ethereum addresses, amounts must be integers, and both arrays must have the same length
    const RECEIVERS = process.env.RECEIVERS ? process.env.RECEIVERS.split(",") : [];
    const AMOUNTS = process.env.AMOUNTS ? process.env.AMOUNTS.split(",").map(value => parseInt(value, 10)) : [];

    if (RECEIVERS.length === 0 || AMOUNTS.length === 0) {
        throw new Error('Missing RECEIVERS or AMOUNTS environment variables');
    }

    if (RECEIVERS.length !== AMOUNTS.length) {
        throw new Error('RECEIVERS and AMOUNTS must have the same length');
    }

    for (const receiver of RECEIVERS) {
        if (!ethers.isAddress(receiver)) {
            throw new Error(`Invalid receiver address: ${receiver}`);
        }
    }

    for (const amount of AMOUNTS) {
        if (isNaN(amount) || amount < 0) {
            throw new Error(`Contains invalid amount`);
        }
    }

    const { gildiManager } = await getNamedAccounts();
    const gildiManagerSigner = await ethers.getSignerOrNull(gildiManager);
    if (!gildiManager || !gildiManagerSigner) {
        throw new Error('Missing named account or signer: gildiManager');
    }

    const gildiManagerDeployment = await deployments.getOrNull('GildiManager');
    if (!gildiManagerDeployment) {
        throw new Error('GildiManager deployment not found');
    }
    const gildiManagerContract = await ethers.getContractAt('GildiManager', gildiManagerDeployment.address, gildiManagerSigner);

    if (!await gildiManagerContract.releaseExists(RELEASE_ID)) {
        throw new Error('Release does not exist, cannot assign shares');
    }

    const totalNumberOfShares = AMOUNTS.reduce((acc, amount) => acc + amount, 0);

    const release = await gildiManagerContract.getReleaseById(RELEASE_ID);
    if (release.unassignedShares < totalNumberOfShares) {
        throw new Error('Not enough unassigned shares to assign');
    }

    const assignments: IGildiManager.UserShareStruct[] = [];
    for (let i = 0; i < RECEIVERS.length; i++) {
        assignments.push({ user: RECEIVERS[i], shares: AMOUNTS[i] });
    }

    const summaryMultiline = `
Release ID: ${RELEASE_ID}
Total number of shares: ${totalNumberOfShares}
Receivers: ${RECEIVERS.join(', ')}
Amounts: ${AMOUNTS.join(', ')}`;

    const confirmed = await confirmActionAsync(`Assign ${totalNumberOfShares} shares to ${assignments.length} addresses?`, false, summaryMultiline);
    if (!confirmed) {
        throw new Error('User cancelled');
    }

    const batchSize = 100;
    let totalAssignedShares = 0;
    let totalAssignedAddresses = 0;
    for (let i = 0; i < assignments.length; i += batchSize) {
        const batch = assignments.slice(i, i + batchSize);
        const batchShares = batch.reduce((acc, assignment) => acc + Number(assignment.shares), 0);
        console.log(`Assigning ${batchShares} shares to ${batch.length} addresses...`);
        await gildiManagerContract.assignShares(RELEASE_ID, batch);

        totalAssignedShares += batchShares;
        totalAssignedAddresses += batch.length;
    }

    console.log(`Assigned ${totalAssignedShares} shares to ${totalAssignedAddresses} addresses for release ${RELEASE_ID}`);
}

main().then(() => process.exit(0)).catch(error => {
    console.error(error);
    process.exit(1);
});