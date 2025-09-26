import hre, { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../utils/confirmAction';
import { GildiExchange__factory, IGildiExchange } from '../../typechain-types';
import { Token } from '../../constants/tokenAddresses';
import { fetchTokenAddress } from '../../utils/fetchTokenInfo';

interface FeeDistribution {
    feeReceiver: FeeReceiver;
    subFeeReceivers: FeeReceiver[];
}

interface FeeReceiver {
    receiverAddress: string;
    value: bigint,
    payoutCurrency?: Token
}

// mapping releaseId => FeeDistributionStruct[].
const releaseExtraFees: { [key: number]: FeeDistribution[] } = {
}

async function main() {
    const RELEASE_ID = process.env.RELEASE_ID ? parseInt(process.env.RELEASE_ID) : undefined;

    if (!hre.network.config.chainId) {
        throw new Error('Chain ID is required');
    }

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

    if (release.initialized) {
        throw new Error(`Release with ID ${RELEASE_ID} is already initialized`);
    }

    const extraFees = releaseExtraFees[RELEASE_ID] || [];

    const extraFeesStruct: IGildiExchange.FeeDistributionStruct[] = [];
    for (const extraFee of extraFees) {
        let extraFeeReceiverPayoutToken;
        if (extraFee.feeReceiver.payoutCurrency) {
            extraFeeReceiverPayoutToken = fetchTokenAddress(extraFee.feeReceiver.payoutCurrency, hre.network.config.chainId);
        } else {
            extraFeeReceiverPayoutToken = ethers.ZeroAddress;
        }

        let subFeeReceiverPayoutTokens: string[] = [];
        if (extraFee.subFeeReceivers) {
            for (const subFee of extraFee.subFeeReceivers) {
                if (subFee.payoutCurrency) {
                    subFeeReceiverPayoutTokens.push(fetchTokenAddress(subFee.payoutCurrency, hre.network.config.chainId));
                } else {
                    subFeeReceiverPayoutTokens.push(ethers.ZeroAddress);
                }
            }
        }

        extraFeesStruct.push({
            feeReceiver: {
                receiverAddress: extraFee.feeReceiver.receiverAddress,
                value: extraFee.feeReceiver.value,
                payoutCurrency: extraFeeReceiverPayoutToken
            },
            subFeeReceivers: extraFee.subFeeReceivers.map((subFee, index) => ({
                receiverAddress: subFee.receiverAddress,
                value: subFee.value,
                payoutCurrency: subFeeReceiverPayoutTokens[index]
            }))
        });
    }

    const detail = `Additional fees: ${JSON.stringify(extraFeesStruct, bigintReplacer)}`;
    const confirmed = await confirmActionAsync(`Initialise Release ${RELEASE_ID}?`, false, detail);
    if (!confirmed) {
        throw new Error('User cancelled');
    }

    await gildiExchangeContract.initializeRelease(RELEASE_ID, extraFeesStruct);

    console.log(`Release ${RELEASE_ID} initialized`);
}

function bigintReplacer(key: any, value: any) {
    return typeof value === 'bigint' ? value.toString() : value;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });