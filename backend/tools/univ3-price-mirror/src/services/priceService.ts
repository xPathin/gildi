import axios from "axios";
import { logger } from "../utils/logger";
import { config } from "../config/config";

export interface PriceData {
    [tokenId: string]: {
        usd: number;
        last_updated_at: number;
    };
}

export interface TokenPrice {
    tokenId: string;
    symbol: string;
    priceUsd: number;
    lastUpdated: Date;
}

export class PriceService {
    private readonly baseUrl = "https://api.coingecko.com/api/v3";
    private readonly apiKey?: string;
    private priceCache: Map<string, TokenPrice> = new Map();

    constructor() {
        this.apiKey = config.coingeckoApiKey;
    }

    /**
     * Fetch current prices for multiple tokens from CoinGecko
     */
    async fetchPrices(tokenIds: string[]): Promise<TokenPrice[]> {
        try {
            logger.info(`Fetching prices for tokens: ${tokenIds.join(", ")}`);

            const url = `${this.baseUrl}/simple/price`;
            const params = {
                ids: tokenIds.join(","),
                vs_currencies: "usd",
                include_last_updated_at: "true",
            };

            const headers: Record<string, string> = {
                Accept: "application/json",
            };

            // Add API key if available (for higher rate limits)
            if (this.apiKey) {
                headers["x-cg-demo-api-key"] = this.apiKey;
            }

            const response = await axios.get<PriceData>(url, {
                params,
                headers,
                timeout: 10000, // 10 second timeout
            });

            const prices: TokenPrice[] = [];

            for (const [tokenId, data] of Object.entries(response.data)) {
                const tokenPrice: TokenPrice = {
                    tokenId,
                    symbol: this.getSymbolFromTokenId(tokenId),
                    priceUsd: data.usd,
                    lastUpdated: new Date(data.last_updated_at * 1000),
                };

                prices.push(tokenPrice);
                this.priceCache.set(tokenId, tokenPrice);

                logger.info(
                    `${tokenPrice.symbol.toUpperCase()}: $${tokenPrice.priceUsd.toFixed(
                        8,
                    )}`,
                );
            }

            logger.info(`Successfully fetched ${prices.length} token prices`);
            return prices;
        } catch (error) {
            logger.error("Failed to fetch prices from CoinGecko:", error);

            // Return cached prices if available
            if (this.priceCache.size > 0) {
                logger.warn("Using cached prices due to API failure");
                return Array.from(this.priceCache.values()).filter((price) =>
                    tokenIds.includes(price.tokenId),
                );
            }

            throw new Error(`Failed to fetch prices: ${error}`);
        }
    }

    /**
     * Get cached price for a specific token
     */
    getCachedPrice(tokenId: string): TokenPrice | null {
        return this.priceCache.get(tokenId) || null;
    }

    /**
     * Check if cached prices are still fresh (within last update interval)
     */
    areCachedPricesFresh(): boolean {
        if (this.priceCache.size === 0) return false;

        const now = Date.now();
        const maxAge = config.priceUpdateIntervalMinutes * 60 * 1000; // Convert to milliseconds

        for (const price of this.priceCache.values()) {
            const age = now - price.lastUpdated.getTime();
            if (age > maxAge) {
                return false;
            }
        }

        return true;
    }

    /**
     * Get all cached prices
     */
    getAllCachedPrices(): TokenPrice[] {
        return Array.from(this.priceCache.values());
    }

    /**
     * Clear price cache
     */
    clearCache(): void {
        this.priceCache.clear();
        logger.debug("Price cache cleared");
    }

    /**
     * Convert CoinGecko token ID to symbol using external config
     */
    getSymbolFromTokenId(
        tokenId: string,
        symbolMap?: Record<string, string>,
    ): string {
        if (symbolMap) {
            return symbolMap[tokenId] || tokenId.toUpperCase();
        }

        // Fallback mapping if no external config provided
        const fallbackMap: Record<string, string> = {
            ethereum: "ETH",
            bitcoin: "BTC",
            "usd-coin": "USDC",
            tether: "USDT",
            chainlink: "LINK",
            uniswap: "UNI",
            optimism: "OP",
            dai: "DAI",
            "wrapped-bitcoin": "WBTC",
            "staked-ether": "STETH",
        };

        return fallbackMap[tokenId] || tokenId.toUpperCase();
    }

    /**
     * Get token prices in the format expected by PriceMirrorService
     */
    async getTokenPrices(
        tokenIds: string[],
    ): Promise<Record<string, { usd: number }> | null> {
        try {
            const url = `${this.baseUrl}/simple/price`;
            const params = {
                ids: tokenIds.join(","),
                vs_currencies: "usd",
                include_last_updated_at: "true",
            };

            const headers: Record<string, string> = {
                Accept: "application/json",
            };

            if (this.apiKey) {
                headers["x-cg-demo-api-key"] = this.apiKey;
            }

            const response = await axios.get<PriceData>(url, {
                params,
                headers,
                timeout: 10000,
            });

            // Convert to expected format
            const result: Record<string, { usd: number }> = {};
            for (const [tokenId, data] of Object.entries(response.data)) {
                result[tokenId] = { usd: data.usd };
            }

            return result;
        } catch (error) {
            logger.error("Failed to fetch token prices:", error);
            return null;
        }
    }

    /**
     * Get supported token IDs for Optimism ecosystem
     */
    static getSupportedTokenIds(): string[] {
        return [
            "ethereum", // ETH
            "usd-coin", // USDC
            "tether", // USDT
            "optimism", // OP
            "dai", // DAI
            "chainlink", // LINK
            "uniswap", // UNI
            "wrapped-bitcoin", // WBTC
        ];
    }
}
