import dotenv from 'dotenv';
import { ethers } from 'ethers';
import { NETWORK_CONFIG } from './util/consts';
import { NetworkWalletConfig } from './util/interfaces';
import { PriceService } from './PriceService';
import { OraclePriceUpdater } from './OraclePriceUpdater';

dotenv.config();

let updaters: OraclePriceUpdater[] = [];

async function main() {
    const activeNetworks = process.env.ACTIVE_NETWORKS?.split(',') ?? [];
    if (activeNetworks.length === 0) {
        throw new Error('No ACTIVE_NETWORKS specified');
    }

    const networkConfigs = activeNetworks.map((network) => {
        const networkChainId = parseInt(network);
        if (isNaN(networkChainId)) {
            throw new Error(`Invalid network chain id ${network}, must be a number`);
        }

        const networkConfig = NETWORK_CONFIG[networkChainId as keyof typeof NETWORK_CONFIG];
        if (!networkConfig) {
            throw new Error(`Invalid network chain id ${network}, no network config found, must be one of ${Object.keys(NETWORK_CONFIG).join(', ')}`);
        }

        const privateKey = process.env[`PRIVATE_KEY_${network}`];
        if (!privateKey) {
            throw new Error(`No PRIVATE_KEY_${network} specified`);
        }

        try {
            const provider = new ethers.JsonRpcProvider(networkConfig.rpcUrl);
            const wallet = new ethers.Wallet(privateKey, provider);

            const config: NetworkWalletConfig = {
                wallet,
                networkConfig
            };

            return config;
        } catch (error: any) {
            throw new Error(`Failed to create wallet with provider for network ${network}: ${error.message}`);
        }
    });

    PriceService.getInstance().start();
    updaters = networkConfigs.map((config) => new OraclePriceUpdater(config));
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully...');
    PriceService.getInstance().shutdown();
    updaters.forEach((updater) => updater.shutdown());
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    PriceService.getInstance().shutdown();
    updaters.forEach((updater) => updater.shutdown());
    process.exit(0);
});