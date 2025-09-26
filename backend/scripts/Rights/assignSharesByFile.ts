import hre, { ethers, deployments, getNamedAccounts } from 'hardhat';
import fs from 'fs-extra';
import Papa from 'papaparse';
import { IGildiManager } from '../../typechain-types';
import { confirmActionAsync } from '../../utils/confirmAction';

interface CsvShare {
    address: string;
    value: number;
}

async function main() {
    const RELEASE_ID = parseInt(process.env.RELEASE_ID ?? "0") || 0;
    if (RELEASE_ID == 0) {
        throw new Error('Missing RELEASE_ID environment variable or invalid value');
    }
    // chain ID
    if (!hre.network.config.chainId) {
        throw new Error('Missing chain ID');
    }
    let RECEIVERS_FILE_PATH = process.env.FILE_PATH ?? `./scripts/Rights/data/${hre.network.config.chainId}/drops/${RELEASE_ID}.csv`;
    if (!fs.existsSync(RECEIVERS_FILE_PATH)) {
        // check default.csv exists, if yes, use.
        if (fs.existsSync(`./scripts/Rights/data/${hre.network.config.chainId}/drops/default.csv`)) {
            RECEIVERS_FILE_PATH = `./scripts/Rights/data/${hre.network.config.chainId}/drops/default.csv`;
        } else {
            throw new Error(`File not found: ${RECEIVERS_FILE_PATH}`);
        }
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
        throw new Error('Release does not exist, cannot assign shares');
    }

    const shares = await parseCSVFromFile(RECEIVERS_FILE_PATH);
    const totalNumberOfShares = shares.reduce((acc, share) => acc + share.value, 0);

    const release = await gildiManagerContract.getReleaseById(RELEASE_ID);
    if (release.unassignedShares < totalNumberOfShares) {
        throw new Error('Not enough unassigned shares to assign');
    }

    const gildiManagerBalanceNative = await ethers.provider.getBalance(gildiManager);
    console.log(`GildiManager balance (native): ${ethers.formatEther(gildiManagerBalanceNative)}`);

    // Group shares by address (ignore case)
    const sharesByAddress: { [key: string]: number } = {};
    for (const share of shares) {
        const address = share.address.toLowerCase();
        sharesByAddress[address] = (sharesByAddress[address] || 0) + share.value;
    }

    // Create share assignments
    const assignments: IGildiManager.UserShareStruct[] = [];
    for (const [address, value] of Object.entries(sharesByAddress)) {
        assignments.push({ user: address, shares: value });
    }

    const balanceGildiManagerEther = ethers.formatEther(await ethers.provider.getBalance(gildiManager));
    console.log("NATIVE BALANCE", balanceGildiManagerEther);
    const confirmed = await confirmActionAsync(`Assign ${totalNumberOfShares} shares to ${assignments.length} addresses?`, false);
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

const parseCSVFromFile = (filePath: string): Promise<CsvShare[]> => {
    return new Promise((resolve, reject) => {
        fs.readFile(filePath, 'utf8', (err, data) => {
            if (err) {
                return reject(err);
            }

            const result = Papa.parse<CsvShare>(data, {
                header: true,
                skipEmptyLines: true,
                transformHeader: (header: string) => header.trim(),
                transform: (value: string, field: string) => {
                    switch (field) {
                        case 'value':
                            return BigInt(value);
                        default:
                            return value;
                    }
                },
                dynamicTyping: true,
            });

            if (result.errors.length) {
                console.error('CSV Parsing errors:', result.errors);
                return reject(result.errors);
            }

            resolve(result.data);
        });
    });
};

main().then(() => process.exit(0)).catch(error => {
    console.error(error);
    process.exit(1);
});