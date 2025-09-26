import { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../../../utils/confirmAction';
import { GildiExchangeFundManager__factory, GildiExchange__factory } from '../../../../typechain-types';

const claimer = "contractAdmin";

async function main() {
    const signer = (await ethers.getNamedSigners())[claimer];
    if (!signer) {
        throw new Error(`Missing signer ${claimer}`);
    }
    const gildiExchangeDeployment = await deployments.get('GildiExchange');
    if (!gildiExchangeDeployment) {
        throw new Error('GildiExchange deployment not found');
    }
    const gildiExchangeContract = GildiExchange__factory.connect(gildiExchangeDeployment.address, signer);
    var claimerRole = (await gildiExchangeContract.getAppEnvironment()).claimerRole;

    if (!await gildiExchangeContract.hasRole(claimerRole, signer.address)) {
        throw new Error(`Signer ${claimer} does not have claimer role, please grant the role first.`);
    }

    const fundManagerAddress = (await gildiExchangeContract.getAppEnvironment()).settings.fundManager;
    console.log(`Fund manager address: ${fundManagerAddress}`);

    const fundManagerContract = GildiExchangeFundManager__factory.connect(fundManagerAddress, signer);

    console.log("Sending claimAll request to claim everything pending.");

    const res = await fundManagerContract['claimAllFunds()']();
    const rec = await res.wait();

    console.log(`ClaimAll done. Transaction hash: ${rec?.hash}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
