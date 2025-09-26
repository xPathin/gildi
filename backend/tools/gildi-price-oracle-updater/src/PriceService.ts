import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

export enum ServiceToken {
    RUST = 0,
    USDC = 1
}

// Map from string token names to enum values
export const TokenNameToEnum: Record<string, ServiceToken> = {
    "RUST": ServiceToken.RUST,
    "USDC": ServiceToken.USDC
};

// Map from enum values to string token names
export const EnumToTokenName: Record<number, string> = {
    [ServiceToken.RUST]: "RUST",
    [ServiceToken.USDC]: "USDC"
};

interface PriceInfo {
    price: number;
    lastUpdated?: Date;
}

export class PriceService {
    private activeTokens: ServiceToken[] = [];

    private static instance: PriceService;

    // Track the current price
    private prices: { [token: number]: PriceInfo } = {};

    // For the initial fetch lazy loading
    private initialFetchPromise: Promise<void> | null = null;

    // Background job tracking
    private running: boolean = false;
    private intervalIds: { [key: string]: NodeJS.Timeout | null } = {};

    private constructor() {
        // Parse string tokens from env to enum values
        const activeTokenEnv = process.env.ACTIVE_TOKENS?.split(',');
        if (activeTokenEnv) {
            for (const token of activeTokenEnv) {
                const trimmedToken = token.trim().toUpperCase();
                const serviceTokenEnum = TokenNameToEnum[trimmedToken];
                if (serviceTokenEnum === undefined) {
                    throw new Error(`Invalid token: ${token}. Must be one of: ${Object.keys(TokenNameToEnum).join(', ')}`);
                }
                this.activeTokens.push(serviceTokenEnum);
            }
        }

        if (this.activeTokens.length === 0) {
            throw new Error('No active tokens specified');
        }

        // Initialize price entries for each active token
        for (const token of this.activeTokens) {
            this.prices[token] = {
                price: 0
            };
        }
    }

    // Singleton accessor
    public static getInstance(): PriceService {
        if (!PriceService.instance) {
            PriceService.instance = new PriceService();
        }
        return PriceService.instance;
    }

    public static async getPriceInfo(token: ServiceToken): Promise<PriceInfo> {
        if (!PriceService.getInstance().running) {
            throw new Error('[PriceService] Not running, please call start() first');
        }

        return await PriceService.getInstance()._getPriceInfo(token);
    }

    public static GetActiveTokens(): ServiceToken[] {
        return PriceService.getInstance().activeTokens;
    }

    public start(): void {
        if (this.running) {
            console.log('[RustPriceService] Already started');
            return;
        }

        this.startUpdateJob();
    }

    // Start a background job using setInterval (non-blocking)
    private startUpdateJob(): void {
        if (this.running) {
            console.log('[RustPriceService] Already running');
            return;
        }

        console.log('[RustPriceService] Starting background job');
        this.running = true;

        // Example: Check price every 2 seconds
        for (const token of this.activeTokens) {
            this.intervalIds[ServiceToken[token]] = setInterval(async () => {
                try {
                    const newPrice = await this.fetchLatestPrice(token);
                    if (newPrice !== this.prices[token].price) {
                        this.prices[token].price = newPrice;
                        console.log(`[RustPriceService] Updated ${EnumToTokenName[token]} price to: ${newPrice}`);
                    } else {
                        console.log(`[RustPriceService] ${EnumToTokenName[token]} price unchanged: ${newPrice}`);
                    }
                    this.prices[token].lastUpdated = new Date(); // track time
                } catch (err) {
                    console.error('[RustPriceService] Failed to update price:', err);
                }
            }, 2000);
        }
    }

    // Graceful shutdown
    public shutdown(): void {
        if (!this.running) {
            console.log('[RustPriceService] Already shutdown');
            return;
        }

        this.running = false;

        for (const token of this.activeTokens) {
            const intervalKey = ServiceToken[token];
            const intervalId = this.intervalIds[intervalKey];
            if (intervalId) {
                clearInterval(intervalId);
                this.intervalIds[intervalKey] = null;
            }
        }

        console.log('[RustPriceService] Shutdown completed');
    }

    private async _getPriceInfo(token: ServiceToken): Promise<PriceInfo> {
        // If we have not done an initial fetch, start one:
        if (!this.prices[token].lastUpdated && !this.initialFetchPromise) {
            // Create and store the promise so multiple callers wait on the same fetch
            this.initialFetchPromise = (async () => {
                const newPrice = await this.fetchLatestPrice(token);
                this.prices[token].price = newPrice;
                this.prices[token].lastUpdated = new Date(); // track when we fetched
            })();
        }

        // If the initial fetch is in progress, wait for it
        if (this.initialFetchPromise) {
            await this.initialFetchPromise;
            // After it finishes once, we can clear out the promise
            this.initialFetchPromise = null;
        }

        // Return the latest price info
        return {
            price: this.prices[token].price,
            lastUpdated: this.prices[token].lastUpdated
        };
    }

    private async fetchLatestPrice(token: ServiceToken): Promise<number> {
        let tokenId;
        if (token === ServiceToken.RUST) {
            tokenId = 33554433;
        } else if (token === ServiceToken.USDC) {
            tokenId = 33554435;
        } else {
            throw new Error(`Invalid token: ${EnumToTokenName[token] || token}`);
        }

        const response = await axios.post('https://api.coda.to/Prices', {
            sourceAsset: tokenId,
            targetAssets: [16777218]
        });

        if (!response.data || !response.data.targetAssetPrices || !response.data.targetAssetPrices[0] || !response.data.targetAssetPrices[0].price) {
            throw new Error(`Invalid response from price API: ${JSON.stringify(response.data)}`);
        }

        return response.data.targetAssetPrices[0].price;
    }
}

interface PriceInfo {
    price: number;
    lastUpdated?: Date;
}