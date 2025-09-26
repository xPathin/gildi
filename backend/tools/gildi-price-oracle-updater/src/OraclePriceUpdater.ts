
import { ethers } from "ethers";
import { EnumToTokenName, PriceService, ServiceToken } from "./PriceService";
import { NetworkWalletConfig } from "./util/interfaces";
import { GildiPriceProvider, GildiPriceProvider__factory } from "./typechain-types";

export class OraclePriceUpdater {
    private intervalId: NodeJS.Timeout | null = null;
    private running = false;
    private contract: GildiPriceProvider;
    private chainId: number;
    private pairIds: { [key: number]: string } = {};
    private updateRunning = false;
    private lastUpdateTime: number = 0;
    private currentPrices: { [key: number]: bigint } = {};
    private pricesInitialized = false;

    private static readonly CHECK_INTERVAL = 5000; // Check every 5 seconds
    private static readonly MIN_UPDATE_INTERVAL = 10000; // Minimum 10 seconds between updates
    private static readonly MAX_UPDATE_INTERVAL = 30000; // Maximum 30 seconds between updates
    private static readonly ORACLE_DECIMALS = 8;

    constructor(config: NetworkWalletConfig) {
        this.chainId = config.networkConfig.chainId;
        if (!ethers.isAddress(config.networkConfig.oracleProviderContractAddress)) {
            throw new Error(`[OraclePriceUpdater ${this.chainId}] Invalid oracle provider contract address, ${config.networkConfig.oracleProviderContractAddress}`);
        }
        this.contract = GildiPriceProvider__factory.connect(config.networkConfig.oracleProviderContractAddress.toString(), config.wallet);

        // Build pair id's.
        for (const token of PriceService.GetActiveTokens()) {
            this.pairIds[token] = ethers.solidityPackedKeccak256(["string"], [`${EnumToTokenName[token]}/USD`]);
        }

        this.startUpdater();
    }

    private startUpdater() {
        this.log(`Starting OraclePriceUpdater`);
        this.running = true;
        this.lastUpdateTime = Date.now(); // Initialize last update time
        this.intervalId = setInterval(async () => {
            try {
                if (this.updateRunning) {
                    this.log(`Update already in progress, skipping`);
                    return;
                }
                this.updateRunning = true;

                if (!this.pricesInitialized) {
                    // Initialize current prices
                    for (const pairId of Object.keys(this.pairIds)) {
                        try {
                            const { price } = await this.contract.getPrice(this.pairIds[parseInt(pairId)]);
                            // Resolve token from pair id
                            const allPairIds = Object.keys(this.pairIds);
                            const token = allPairIds.find((id) => this.pairIds[parseInt(id)] === this.pairIds[parseInt(pairId)]);
                            if (!token) {
                                throw new Error(`Failed to resolve token from pair id ${pairId}`);
                            }
                            this.currentPrices[parseInt(token)] = price;
                        } catch (err) {
                            this.error(`Failed to get price for pair id ${pairId}:`, err);
                        }
                    }
                    this.pricesInitialized = true;

                    console.log("Prices initialize", this.currentPrices);
                }

                const currentTime = Date.now();
                const timeElapsedSinceLastUpdate = currentTime - this.lastUpdateTime;

                // Fetch new prices
                let newPrices: { [key: number]: { price: number; formatted: bigint } } = [];
                for (const token of PriceService.GetActiveTokens()) {
                    const { price } = await PriceService.getPriceInfo(token);
                    var newPriceFormatted = this.priceToOracleFormat(price);
                    newPrices[token] = { price, formatted: newPriceFormatted };
                }

                // Check if any price has changed
                const priceChanged = this.hasPriceChanged(newPrices);

                // Determine if we should update based on our rules
                const minElapsed = timeElapsedSinceLastUpdate >= OraclePriceUpdater.MIN_UPDATE_INTERVAL;
                const maxElapsed = timeElapsedSinceLastUpdate >= OraclePriceUpdater.MAX_UPDATE_INTERVAL;

                if ((minElapsed && priceChanged) || maxElapsed) {
                    this.log(`Updating prices - minElapsed: ${minElapsed}, priceChanged: ${priceChanged}, maxElapsed: ${maxElapsed}, timeElapsed: ${timeElapsedSinceLastUpdate}ms`);

                    const newPriceUpdates: GildiPriceProvider.PriceUpdateStruct[] = [];
                    for (const [token, { formatted }] of Object.entries(newPrices)) {
                        newPriceUpdates.push({
                            pairId: this.pairIds[parseInt(token)],
                            price: formatted,
                            decimals: OraclePriceUpdater.ORACLE_DECIMALS
                        });
                    }

                    console.log(`[OraclePriceUpdater ${this.chainId}] New price data:`, newPriceUpdates);
                    const res = await this.contract["setPriceData((bytes32,uint256,uint8)[])"](newPriceUpdates);

                    await res.wait();
                    this.log(`Sent on-chain price updates.`);

                    // Update current prices and last update time
                    for (const token of PriceService.GetActiveTokens()) {
                        const tokenNum = parseInt(token.toString());
                        if (this.currentPrices[tokenNum] !== newPrices[tokenNum].formatted) {
                            this.log(`Price updated on-chain to: ${newPrices[tokenNum].price} for ${EnumToTokenName[tokenNum]}`);
                        } else {
                            this.log(`Price unchanged on-chain for ${EnumToTokenName[tokenNum]}`);
                        }
                        this.currentPrices[tokenNum] = newPrices[tokenNum].formatted;
                    }

                    this.lastUpdateTime = Date.now();
                } else {
                    this.log(`Skipping price update - minElapsed: ${minElapsed}, priceChanged: ${priceChanged}, maxElapsed: ${maxElapsed}, timeElapsed: ${timeElapsedSinceLastUpdate}ms`);
                }
            } catch (err) {
                this.error(`Failed to update price:`, err);
            } finally {
                this.updateRunning = false;
            }
        }, OraclePriceUpdater.CHECK_INTERVAL);
    }

    private hasPriceChanged(newPrices: { [key: number]: { price: number; formatted: bigint } }): boolean {
        // If we don't have current prices yet, consider it changed
        if (Object.keys(this.currentPrices).length === 0) return true;

        for (const token of PriceService.GetActiveTokens()) {
            const tokenNum = parseInt(token.toString());
            if (!this.currentPrices[tokenNum] || this.currentPrices[tokenNum] !== newPrices[tokenNum].formatted) {
                return true;
            }
        }
        return false;
    }

    private priceToOracleFormat(price: number): bigint {
        return ethers.parseUnits(price.toString(), OraclePriceUpdater.ORACLE_DECIMALS);
    }

    public shutdown() {
        if (!this.running) {
            this.log(`Already shutdown`);
        }
        this.running = false;
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        this.log(`Shutdown completed`);
    }

    private log(message: string, ...params: any[]) {
        console.log(`[OraclePriceUpdater ${this.chainId}] ${message}`, ...params);
    }

    private error(message: string, ...params: any[]) {
        console.error(`[OraclePriceUpdater ${this.chainId}] ${message}`, ...params);
    }
}