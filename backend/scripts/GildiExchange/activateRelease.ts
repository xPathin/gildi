import hre, { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../utils/confirmAction';
import { GildiExchange__factory, IGildiExchange } from '../../typechain-types';

async function main() {
    const RELEASE_ID = process.env.RELEASE_ID ? parseInt(process.env.RELEASE_ID) : undefined;

    if (!RELEASE_ID) {
        throw new Error("RELEASE_ID is required");
    }

    const { contractAdmin } = await getNamedAccounts();
    if (!contractAdmin) {
        throw new Error('Missing named accounts');
    }
    const contractAdminSigner = await ethers.getSigner(contractAdmin);

    const gildiExchangeDeployment = await deployments.get('GildiExchange');
    if (!gildiExchangeDeployment) {
        throw new Error('GildiExchange deployment not found');
    }
    const gildiExchangeContract = GildiExchange__factory.connect(gildiExchangeDeployment.address, contractAdminSigner);
    const release = await gildiExchangeContract.getReleaseById(RELEASE_ID);

    if (!release.initialized) {
        throw new Error(`Release with ID ${RELEASE_ID} is not initialized`);
    }

    if (release.active) {
        throw new Error(`Release with ID ${RELEASE_ID} is already active`);
    }

    // const confirmed = await confirmActionAsync(`Activate Release ${RELEASE_ID}?`, false);
    // if (!confirmed) {
    //     throw new Error('User cancelled');
    // }
    await gildiExchangeContract.setReleaseActive(RELEASE_ID, true);

    console.log(`Release ${RELEASE_ID} activated`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });