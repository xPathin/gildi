import { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../../../utils/confirmAction';
import { GildiExchange__factory } from '../../../../typechain-types';

const roleReceivers = ["contractAdmin"];

async function main() {
    const { defaultAdmin } = await ethers.getNamedSigners();
    if (!defaultAdmin) {
        throw new Error('Missing default admin signer');
    }
    const gildiExchangeDeployment = await deployments.get('GildiExchange');
    if (!gildiExchangeDeployment) {
        throw new Error('GildiExchange deployment not found');
    }
    const gildiExchangeContract = GildiExchange__factory.connect(gildiExchangeDeployment.address, defaultAdmin);
    var claimerRole = (await gildiExchangeContract.getAppEnvironment()).claimerRole;

    for (const roleReceiver of roleReceivers) {
        console.log(`Processing role receiver: ${roleReceiver}`);
        // Check if roleReceiver is ether address, if not try to get from named accounts.
        const roleReceiverAddress = ethers.isAddress(roleReceiver) ? roleReceiver : (await getNamedAccounts())[roleReceiver];    
        console.log(`Role receiver address: ${roleReceiverAddress}`);

        if (!roleReceiverAddress) {
            throw new Error(`Missing role receiver: ${roleReceiver}`);
        }

        if (!await gildiExchangeContract.hasRole(claimerRole, roleReceiverAddress)) {
            console.log(`Granting claimer role to ${roleReceiverAddress}`);
            await gildiExchangeContract.grantRole(claimerRole, roleReceiverAddress);   
        }else {
            console.log(`Claimer role already granted to ${roleReceiverAddress}`);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
