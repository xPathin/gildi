import hre, { deployments, ethers, getNamedAccounts } from 'hardhat';
import { confirmActionAsync } from '../../../utils/confirmAction';
import { BigNumberish } from 'ethers';
import fs from 'fs';
import { GildiExchange__factory, GildiManager__factory, ERC20__factory, IGildiExchange, IERC20__factory } from '../../../typechain-types';
import { fetchTokenAddress, fetchTokenAddressOrNull } from '../../../utils/fetchTokenInfo';
import { Token } from '../../../constants/tokenAddresses';

interface FeeDistribution {
    feeReceiver: FeeReceiver;
    subFeeReceivers: FeeReceiver[];
}

interface FeeReceiver {
    receiverAddress: string;
    value: bigint; // In BPS
    payoutCurrency?: Token
}

const defaultInitialSaleFees: FeeDistribution[] = [{
    feeReceiver: {
        receiverAddress: "marketplaceFeeReceiver",
        value: 500n, // 5%
        payoutCurrency: Token.USDC
    },
    subFeeReceivers: []
}];

const individualInitialSaleFees: { [key: number]: { [key: number]: FeeDistribution[] } } = {
    1075: {
        // 1: [
        //     {
        //         feeReceiver: {
        //             receiver: "0x7384a1180321A5de3a486c64188aBFF98778C65B",
        //             value: 200n,
        //             payoutCurrency: Token.USDC
        //         },
        //         subFeeReceivers: []
        //     }
        // ]
    }
};

async function main() {
    if (!hre.network.config.chainId) {
        throw new Error('Hardhat network chain ID not configured');
    }

    let saleTokenAddress: string | null | undefined = process.env.TOKEN;
    if (saleTokenAddress) {
        console.warn('TOKEN environment variable was set, by default the system will use USDC, make sure this is correct!');
    }
    else {
        saleTokenAddress = fetchTokenAddressOrNull(Token.USDC, hre.network.config.chainId);
        if (!saleTokenAddress) {
            throw new Error(`Sale token address for USDC not found on chain ${hre.network.config.chainId}`);
        }
    }

    let payoutCurrency: string | null | undefined = process.env.PAYOUT_CURRENCY;
    if (payoutCurrency) {
        console.warn('PAYOUT_CURRENCY environment variable was set, by default the system will use USDC, make sure this is correct!');
    }
    else {
        payoutCurrency = fetchTokenAddressOrNull(Token.USDC, hre.network.config.chainId);
        if (!payoutCurrency) {
            throw new Error(`Payout currency address for USDC not found on chain ${hre.network.config.chainId}`);
        }
    }

    const RELEASE_ID = process.env.RELEASE_ID ? parseInt(process.env.RELEASE_ID) : undefined;
    if (!RELEASE_ID) {
        throw new Error("RELEASE_ID is required");
    }

    const SELLER = process.env.SELLER && ethers.isAddress(process.env.SELLER) ? process.env.SELLER : undefined;
    if (!SELLER) {
        throw new Error("SELLER is required and must be a valid Ethereum address");
    }

    const SALE_START = process.env.SALE_START ? parseInt(process.env.SALE_START) : 0;
    if (isNaN(SALE_START) || SALE_START < 0) {
        throw new Error("SALE_START must be a valid unix timestamp");
    }

    const MAX_BUY = process.env.MAX_BUY ? parseInt(process.env.MAX_BUY) : 0;
    if (isNaN(MAX_BUY) || MAX_BUY < 0) {
        throw new Error("MAX_BUY must be a valid number");
    }

    const QUANTITIES = process.env.QUANTITIES ? process.env.QUANTITIES.split(",").map(value => parseInt(value, 10)) : []
    const PRICES = process.env.PRICES ? process.env.PRICES.split(",").map(Number) : [];

    if (QUANTITIES.length === 0 || PRICES.length === 0) {
        throw new Error("QUANTITIES and PRICES must have at least one element");
    }

    if (QUANTITIES.length !== PRICES.length) {
        throw new Error("QUANTITIES and PRICES must have the same length");
    }

    for (const price of PRICES) {
        if (isNaN(price) || price < 0) {
            throw new Error("PRICES contains an invalid value");
        }
    }

    for (const quantity of QUANTITIES) {
        if (isNaN(quantity) || quantity < 0) {
            throw new Error("QUANTITIES contains an invalid value");
        }
    }

    const IS_WHITELIST = process.env.IS_WHITELIST
        ? ["1", "true"].includes(process.env.IS_WHITELIST.toLowerCase())
        : false;

    let WHITELIST: string[] = [];
    if (IS_WHITELIST) {
        if (!hre.network.config.chainId) {
            throw new Error('Hardhat network chain ID not configured, required for whitelist');
        }

        WHITELIST = parseWhitelist(RELEASE_ID);
        if (WHITELIST.length === 0) {
            throw new Error("Whitelist is empty");
        }
    }

    const WHITELIST_DURATION = IS_WHITELIST && process.env.WHITELIST_DURATION ? parseInt(process.env.WHITELIST_DURATION) : 0;
    if (isNaN(WHITELIST_DURATION) || WHITELIST_DURATION < 0) {
        throw new Error("Provided WHITELIST_DURATION is not a valid number");
    }

    const INITIAL_SALE_DURATION = process.env.INITIAL_SALE_DURATION ? parseInt(process.env.INITIAL_SALE_DURATION) : 0;
    if (isNaN(INITIAL_SALE_DURATION) || INITIAL_SALE_DURATION < 0) {
        throw new Error("Provided INITIAL_SALE_DURATION is not a valid number");
    }

    if (IS_WHITELIST && WHITELIST_DURATION > 0 && INITIAL_SALE_DURATION > 0) {
        if (INITIAL_SALE_DURATION < WHITELIST_DURATION) {
            throw new Error("Initial sale duration must be greater than whitelist duration");
        }
    }

    const { marketplaceManager } = await getNamedAccounts();
    const marketplaceManagerSigner = await ethers.getSignerOrNull(marketplaceManager);
    if (!marketplaceManagerSigner || !marketplaceManager) {
        throw new Error('Missing named account Signer: contractManager');
    }

    const gildiExchangeDeployment = await deployments.get('GildiExchange');
    const gildiManagerDeployment = await deployments.get('GildiManager');
    if (!gildiExchangeDeployment || !gildiManagerDeployment) {
        throw new Error('GildiExchange or GildiManager deployment not found');
    }

    const gildiExchangeContract = GildiExchange__factory.connect(gildiExchangeDeployment.address, marketplaceManagerSigner);
    const gildiManagerContract = GildiManager__factory.connect(gildiManagerDeployment.address, marketplaceManagerSigner);

    if (!gildiManagerContract.releaseExists(RELEASE_ID)) {
        throw new Error(`Release with ID ${RELEASE_ID} does not exist`);
    }

    if (!await gildiManagerContract.isLocked(RELEASE_ID)) {
        throw new Error(`Release with ID ${RELEASE_ID} is not locked`);
    }

    const release = await gildiExchangeContract.getReleaseById(RELEASE_ID);
    if (!release.initialized) {
        throw new Error(`Release with ID ${RELEASE_ID} is not initialized`);
    }

    if (await gildiExchangeContract.isInInitialSale(RELEASE_ID)) {
        throw new Error(`Release with ID ${RELEASE_ID} is already in initial sale`);
    }

    if (release.active) {
        throw new Error(`Release with ID ${RELEASE_ID} is already active`);
    }

    if (release.isCancelling) {
        throw new Error(`Release with ID ${RELEASE_ID} is currently cancelling`);
    }

    const totalBalanceNeeded = QUANTITIES.reduce((acc, quantity) => BigInt(acc) + BigInt(quantity), 0n);
    if (await gildiManagerContract.getAvailableBalance(RELEASE_ID, SELLER) < totalBalanceNeeded) {
        throw new Error(`Seller does not have enough free balance for the initial sale`);
    }

    const appEnv = await gildiExchangeContract.getAppEnvironment();
    const usdDecimals = appEnv.settings.priceAskDecimals;
    let pricesDecimals = PRICES.map(price => ethers.parseUnits(price.toString(), usdDecimals));

    const saleStartString = SALE_START > 0 ? new Date(SALE_START * 1000).toUTCString() : "Now";

    const initialSaleFees = await MapFeeDistribution(individualInitialSaleFees[hre.network.config.chainId]?.[RELEASE_ID] || defaultInitialSaleFees, hre.network.config.chainId);

    // All checks complete, let's create the initial sale
    const releaseSummaryMultiline = `
Release ID: ${RELEASE_ID}
Seller: ${SELLER}
Quantities: ${QUANTITIES.join(", ")}
Prices in USD: ${PRICES.join(", ")}
Prices in USD Raw: ${pricesDecimals.map(price => price.toString()).join(", ")}
Initial Sale Duration: ${INITIAL_SALE_DURATION}
Sale Start: ${saleStartString}
Max Buy: ${MAX_BUY}
Is Whitelist: ${IS_WHITELIST}
Whitelist Duration: ${WHITELIST_DURATION}
Whitelist Entries: ${WHITELIST.length}
Sale Token: ${saleTokenAddress}
Payout Currency: ${payoutCurrency}
Initial Sale Fees: ${JSON.stringify(initialSaleFees, (key, value) => typeof value === 'bigint' ? value.toString() : value)}`;

    console.log(`L2 Funds Signer: ${marketplaceManager}: ${ethers.formatEther((await ethers.provider.getBalance(marketplaceManager)).toString())}`);

    const confirmed = await confirmActionAsync(`Create Initial Sale for Release ${RELEASE_ID}?`, false, releaseSummaryMultiline);
    if (!confirmed) {
        throw new Error('User cancelled');
    }

    await gildiExchangeContract.createInitialSale({
        releaseId: RELEASE_ID,
        assetQuantities: QUANTITIES.map(q => BigInt(q)),
        assetPrices: pricesDecimals,
        seller: SELLER,
        maxBuy: MAX_BUY,
        start: SALE_START,
        duration: INITIAL_SALE_DURATION,
        whitelist: IS_WHITELIST,
        whitelistAddresses: WHITELIST,
        whitelistDuration: WHITELIST_DURATION,
        initialSaleCurrency: saleTokenAddress,
        payoutCurrency,
        fees: initialSaleFees
    });

    console.log(`Initial Sale for Release ${RELEASE_ID} created`);
}

async function MapFeeDistribution(feeDistributions: FeeDistribution[], chainId: number): Promise<IGildiExchange.FeeDistributionStruct[]> {
    async function resolveReceiverAddress(address: string): Promise<string> {
        if (!ethers.isAddress(address)) {
            const namedAccounts = await hre.getNamedAccounts();
            if (!namedAccounts[address]) {
                throw new Error(`Invalid address: ${address}`);
            }
            return namedAccounts[address];
        }
        return address;
    }

    // Process all fee receivers in parallel
    const mappedDistributions = await Promise.all(
        feeDistributions.map(async (feeDistribution) => {
            // Resolve main fee receiver
            const resolvedFeeReceiver = {
                receiverAddress: await resolveReceiverAddress(feeDistribution.feeReceiver.receiverAddress),
                value: feeDistribution.feeReceiver.value,
                payoutCurrency: feeDistribution.feeReceiver.payoutCurrency
                    ? fetchTokenAddressOrNull(feeDistribution.feeReceiver.payoutCurrency, chainId) ?? ethers.ZeroAddress
                    : ethers.ZeroAddress
            };

            // Resolve all sub fee receivers in parallel
            const resolvedSubFeeReceivers = await Promise.all(
                feeDistribution.subFeeReceivers.map(async (subFeeReceiver) => ({
                    receiverAddress: await resolveReceiverAddress(subFeeReceiver.receiverAddress),
                    value: subFeeReceiver.value,
                    payoutCurrency: subFeeReceiver.payoutCurrency
                        ? fetchTokenAddressOrNull(subFeeReceiver.payoutCurrency, chainId) ?? ethers.ZeroAddress
                        : ethers.ZeroAddress
                }))
            );

            return {
                feeReceiver: resolvedFeeReceiver,
                subFeeReceivers: resolvedSubFeeReceivers
            };
        })
    );

    return mappedDistributions;
}


function parseWhitelist(releaseId: number): string[] {
    const filePath = `./scripts/GildiExchange/initialSale/data/${hre.network.config.chainId}/whitelist/${releaseId}`;
    if (!fs.existsSync(filePath)) {
        throw new Error(`Whitelist file for release ${releaseId} not found, please create one at ${filePath}`);
    }

    // Read file line by line and for each line check if it is a valid address, if yes, add to whitelist, if not throw error
    const addresses: string[] = [];
    const content = fs.readFileSync(filePath, 'utf-8');

    const lines = content.split('\n');
    for (const line of lines) {
        if (line.trim() === '') {
            continue;
        }

        if (!ethers.isAddress(line)) {
            throw new Error(`Invalid address in whitelist: ${line}`);
        }

        addresses.push(line);
    }

    return addresses;
}

main().then(() => process.exit(0)).catch((error) => {
    console.error(error);
    process.exit(1);
});