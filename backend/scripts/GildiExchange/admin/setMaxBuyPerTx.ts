import { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../../utils/confirmAction';
import { IGildiExchange, GildiExchange__factory } from '../../../typechain-types';

async function main() {
    const MAX_BUY = process.env.MAX_BUY ? parseInt(process.env.MAX_BUY) : undefined;

    if (MAX_BUY === undefined || isNaN(MAX_BUY)) {
        throw new Error("MAX_BUY is required");
    }

    if (MAX_BUY < 0) {
        throw new Error("MAX_BUY must be greater than or equal to 0");
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
    const appEnv = await gildiExchangeContract.getAppEnvironment();
    const currentMaxBuy = appEnv.settings.maxBuyPerTransaction;

    if (BigInt(MAX_BUY) === currentMaxBuy) {
        console.log(`Max buy per transaction is already set to ${MAX_BUY}`);
        return;
    }

    const confirmed = await confirmActionAsync(`Set max buy per transaction to ${MAX_BUY}?`, false);
    if (!confirmed) {
        throw new Error('User cancelled');
    }
    await gildiExchangeContract.setMaxBuyPerTransaction(MAX_BUY);

    console.log(`Max buy per transaction set to ${MAX_BUY}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });