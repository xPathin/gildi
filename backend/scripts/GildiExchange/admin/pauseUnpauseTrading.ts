import { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../../utils/confirmAction';
import { GildiExchange__factory } from '../../../typechain-types';

async function main() {
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
    const paused = await gildiExchangeContract.paused();
    console.log(`Trading is currently ${paused ? 'paused' : 'unpaused'}`);
    if (paused) {
        const confirmed = await confirmActionAsync('Unpause trading?', false);
        if (!confirmed) {
            throw new Error('User cancelled');
        }
        await gildiExchangeContract.unpause();
        console.log('Trading unpaused');
    } else {
        const confirmed = await confirmActionAsync('Pause trading?', false);
        if (!confirmed) {
            throw new Error('User cancelled');
        }
        await gildiExchangeContract.pause();
        console.log('Trading paused');
    }

    console.log(`Done, trading is now ${paused ? 'unpaused' : 'paused'}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });