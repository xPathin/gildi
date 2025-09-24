import { ethers, Wallet, Provider } from "ethers";
import { logger } from "../utils/logger";
import { PriceService } from "./priceService";
import { ConfigService } from "./configService";
import {
    UniswapUpdateService,
    type UniswapUpdateConfig,
} from "./uniswapUpdateService";
import type { PoolConfig, TokenInfo } from "./configService";

export class AppService {
    private priceService: PriceService;
    private configService: ConfigService;
    private uniswapUpdateService: UniswapUpdateService;
    private provider: Provider;
    private wallet: Wallet;
    private isRunning = false;
    private currentInterval: NodeJS.Timeout | null = null;

    constructor() {
        this.configService = new ConfigService();
        this.priceService = new PriceService();

        // Initialize wallet and provider
        const rpcUrl = process.env["RPC_URL"];
        const privateKey = process.env["PRIVATE_KEY"];

        if (!rpcUrl || !privateKey) {
            throw new Error(
                "RPC_URL and PRIVATE_KEY environment variables are required",
            );
        }

        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.wallet = new ethers.Wallet(privateKey, this.provider);

        // Initialize Uniswap update service with the wallet
        this.uniswapUpdateService = new UniswapUpdateService(this.wallet);
    }

    /**
     * Start the price mirroring service
     * This will continuously fetch prices and update Uniswap pools
     */
    async start(): Promise<void> {
        if (this.isRunning) {
            logger.warn("Price mirror service is already running");
            return;
        }

        this.isRunning = true;
        logger.info("Starting App Service...");

        // Load configuration first
        await this.configService.loadConfig();

        // Display initial configuration
        await this.displayConfiguration();

        // Perform initial price update
        await this.updatePoolPrices();

        // Schedule periodic updates (default to 5 minutes if not configured)
        const intervalMinutes = process.env["PRICE_UPDATE_INTERVAL_MINUTES"]
            ? parseInt(process.env["PRICE_UPDATE_INTERVAL_MINUTES"])
            : 5;
        const intervalMs = intervalMinutes * 60 * 1000;
        logger.info(
            `Scheduling price updates every ${intervalMinutes} minutes`,
        );

        this.currentInterval = setInterval(async () => {
            try {
                await this.updatePoolPrices();
            } catch (error) {
                logger.error("Error in scheduled price update:", error);
            }
        }, intervalMs);
    }

    /**
     * Stop the price mirroring loop
     */
    stop(): void {
        if (!this.isRunning) {
            logger.warn("Price mirror service is not running");
            return;
        }

        logger.info("Stopping Price Mirror Service");

        this.isRunning = false;

        if (this.currentInterval) {
            clearInterval(this.currentInterval);
            this.currentInterval = null;
        }

        logger.info("Price Mirror Service stopped");
    }

    /**
     * Check if service is running
     */
    isServiceRunning(): boolean {
        return this.isRunning;
    }

    /**
     * Update pool prices based on CoinGecko data
     * This is the core function that mirrors prices to Uniswap pools
     */
    async updatePoolPrices(): Promise<void> {
        try {
            logger.info("\n === UPDATING POOL PRICES ===");

            // Get unique symbols from all configured pools
            const pools = this.configService.getPools();
            const tokens = this.configService.getTokens();
            const symbols = new Set<string>();

            pools.forEach((pool) => {
                symbols.add(pool.base);
                symbols.add(pool.quote);
            });

            const symbolsArray = Array.from(symbols);
            logger.info(
                `Fetching prices for tokens: ${symbolsArray.join(", ")}`,
            );

            // Map token symbols to CoinGecko IDs for price fetching
            const symbolToCoinGeckoId =
                this.configService.getCoinGeckoMapping();
            const coinGeckoIds = symbolsArray
                .map((symbol) => symbolToCoinGeckoId[symbol])
                .filter((id): id is string => Boolean(id));

            if (coinGeckoIds.length === 0) {
                logger.error("No CoinGecko IDs found for configured tokens");
                return;
            }

            // Fetch prices from CoinGecko
            const prices = await this.priceService.getTokenPrices(coinGeckoIds);

            if (!prices || Object.keys(prices).length === 0) {
                logger.error("Failed to fetch prices from CoinGecko");
                return;
            }

            // Create symbol-to-price mapping
            const symbolPrices: Record<string, number> = {};
            symbolsArray.forEach((symbol) => {
                const coinGeckoId = symbolToCoinGeckoId[symbol];
                if (coinGeckoId && prices[coinGeckoId]) {
                    symbolPrices[symbol] = prices[coinGeckoId].usd;
                }
            });

            // FAIL-FAST: Validate that ALL required pool tokens have prices
            const missingPrices: string[] = [];
            symbolsArray.forEach((symbol) => {
                if (
                    !(symbol in symbolPrices) ||
                    symbolPrices[symbol] === undefined
                ) {
                    missingPrices.push(symbol);
                }
            });

            if (missingPrices.length > 0) {
                const errorMsg = `CRITICAL: Missing prices for pool tokens: ${missingPrices.join(
                    ", ",
                )}. Cannot proceed with pool updates.`;
                logger.error(errorMsg);
                throw new Error(errorMsg);
            }

            // Log price information for each configured pool
            for (const pool of pools) {
                this.logPoolPriceInfo(pool, symbolPrices, tokens);
            }

            // Prepare data for Uniswap update service
            await this.callUniswapUpdateService(symbolPrices);

            logger.info("Price fetching completed");
        } catch (error) {
            logger.error("Error updating pool prices:", error);
            throw error;
        }
    }

    /**
     * Call UniswapUpdateService with all required data
     */
    private async callUniswapUpdateService(
        symbolPrices: Record<string, number>,
    ): Promise<void> {
        try {
            const pools = this.configService.getPools();
            const tokens = this.configService.getTokens();
            const uniswapV3 = this.configService.getUniswapV3Addresses();
            const liquidityUsd = this.configService.getLiquidityUsd();

            // Convert our config format to UniswapUpdateConfig format
            const updateConfig: UniswapUpdateConfig = {
                tokens: Object.fromEntries(
                    Object.entries(tokens).map(([symbol, tokenInfo]) => [
                        symbol,
                        {
                            address: tokenInfo.address,
                            decimals: tokenInfo.decimals,
                            symbol: tokenInfo.symbol,
                        },
                    ]),
                ),
                prices: symbolPrices,
                pools: pools.map((pool) => ({
                    base: pool.base,
                    quote: pool.quote,
                    feeTier: pool.feeTier,
                })),
                liquidityUsd,
                uniswapV3,
            };

            // Call the UniswapUpdateService to display the data
            await this.uniswapUpdateService.executeUpdate(updateConfig);
        } catch (error) {
            logger.error("Error calling Uniswap update service:", error);
        }
    }

    /**
     * Log price information for a specific pool (no Uniswap updates)
     */
    private logPoolPriceInfo(
        pool: PoolConfig,
        prices: Record<string, number>,
        tokens: Record<string, TokenInfo>,
    ): void {
        try {
            const baseToken = tokens[pool.base];
            const quoteToken = tokens[pool.quote];
            const basePrice = prices[pool.base];
            const quotePrice = prices[pool.quote];

            if (!baseToken || !quoteToken) {
                logger.error(
                    `Token config not found for pool ${pool.base}/${pool.quote}`,
                );
                return;
            }

            if (!basePrice || !quotePrice) {
                logger.error(
                    `Price not found for pool ${pool.base}/${pool.quote}`,
                );
                return;
            }

            // Calculate the price ratio (base/quote price)
            const priceRatio = basePrice / quotePrice;

            logger.info(`\n Pool ${pool.base}/${pool.quote}:`);
            logger.info(`   ${pool.base}: $${basePrice.toFixed(8)}`);
            logger.info(`   ${pool.quote}: $${quotePrice.toFixed(8)}`);
            logger.info(`   Price ratio: ${priceRatio.toFixed(6)}`);
            logger.info(`   Fee tier: ${pool.feeTier / 10000}%`);
        } catch (error) {
            logger.error(
                `Error logging pool info ${pool.base}/${pool.quote}:`,
                error,
            );
        }
    }

    /**
     * Display service configuration
     */
    private async displayConfiguration(): Promise<void> {
        try {
            const pools = this.configService.getPools();
            const tokens = this.configService.getTokens();
            const uniswapV3 = this.configService.getUniswapV3Addresses();
            const liquidityUsd = this.configService.getLiquidityUsd();

            logger.info("\n === CONFIGURATION ===");
            logger.info(
                `Network: ${process.env["NETWORK_NAME"] || "Optimism Sepolia"}`,
            );
            logger.info(`RPC: ${process.env["RPC_URL"] || "Not configured"}`);
            logger.info(`Wallet: ${this.getWalletAddress()}`);

            const balance = await this.getWalletBalance();
            logger.info(`Balance: ${balance} ETH`);

            logger.info(
                `Target Liquidity: $${liquidityUsd.toLocaleString()} per pool`,
            );
            logger.info(
                `Update Interval: ${
                    process.env["PRICE_UPDATE_INTERVAL_MINUTES"] || 5
                } minutes`,
            );

            logger.info(`Pools to manage: ${pools.length}`);
            pools.forEach((pool, index) => {
                logger.info(
                    `   ${index + 1}. ${pool.base}/${pool.quote} (${
                        pool.feeTier / 10000
                    }%)`,
                );
            });

            logger.info(`Uniswap V3 Contracts:`);
            logger.info(`   Factory: ${uniswapV3.factory}`);
            logger.info(`   Position Manager: ${uniswapV3.positionManager}`);
            logger.info(`   Swap Router: ${uniswapV3.swapRouter}`);
            logger.info(`   Quoter: ${uniswapV3.viewQuoter}`);

            logger.info(`Tokens configured: ${Object.keys(tokens).length}`);
            Object.entries(tokens).forEach(([symbol, token]) => {
                logger.info(
                    `   ${symbol}: ${(token as TokenInfo).address} (${
                        (token as TokenInfo).decimals
                    } decimals)`,
                );
            });
        } catch (error) {
            logger.error("Error displaying configuration:", error);
        }
    }

    /**
     * Get the wallet address
     */
    getWalletAddress(): string {
        return this.wallet.address;
    }

    /**
     * Get the wallet balance in ETH
     */
    async getWalletBalance(): Promise<string> {
        const balance = await this.provider.getBalance(this.wallet.address);
        return ethers.formatEther(balance);
    }

    /**
     * Perform a manual price update
     */
    async performManualUpdate(): Promise<void> {
        logger.info("Performing manual price update...");
        await this.updatePoolPrices();
    }

    /**
     * Check if service is currently running
     */
    getIsRunning(): boolean {
        return this.isRunning;
    }

    /**
     * Get service status
     */
    getStatus(): { isRunning: boolean; walletAddress: string } {
        return {
            isRunning: this.isRunning,
            walletAddress: this.wallet.address,
        };
    }
}
