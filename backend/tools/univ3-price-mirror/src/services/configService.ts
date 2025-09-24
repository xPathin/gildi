import * as fs from "fs";
import { logger } from "../utils/logger";

export interface TokenInfo {
    address: string;
    decimals: number;
    symbol: string;
}

export interface PoolConfig {
    base: string;
    quote: string;
    feeTier: number;
}

export interface UniswapV3Contracts {
    factory: string;
    positionManager: string;
    swapRouter: string;
    viewQuoter: string;
}

export interface AppConfig {
    tokens: Record<string, TokenInfo>;
    pools: PoolConfig[];
    liquidityUsd: number;
    uniswapV3: UniswapV3Contracts;
    coinGeckoMapping: Record<string, string>;
}

export class ConfigService {
    private config: AppConfig | null = null;
    private configPath: string;

    constructor() {
        this.configPath = process.env["CONFIG_PATH"] || "config.json";
    }

    /**
     * Load configuration from JSON file - FAILS if file missing or invalid
     */
    async loadConfig(): Promise<AppConfig> {
        logger.info(`Loading configuration from: ${this.configPath}`);

        // Check if config file exists
        if (!fs.existsSync(this.configPath)) {
            throw new Error(
                `Config file not found: ${this.configPath}. Please create the config file.`,
            );
        }

        try {
            // Read and parse config file
            const configData = fs.readFileSync(this.configPath, "utf-8");
            const parsedConfig = JSON.parse(configData) as AppConfig;

            // Validate configuration
            this.validateConfig(parsedConfig);

            this.config = parsedConfig;
            logger.info(`Configuration loaded successfully`);
            logger.info(`Found ${parsedConfig.pools.length} pools configured`);

            return parsedConfig;
        } catch (error) {
            if (error instanceof SyntaxError) {
                throw new Error(
                    `Config file contains invalid JSON: ${error.message}`,
                );
            }
            throw error;
        }
    }

    /**
     * Get loaded configuration
     */
    getConfig(): AppConfig {
        if (!this.config) {
            throw new Error(
                "Configuration not loaded. Call loadConfig() first.",
            );
        }
        return this.config;
    }

    /**
     * Get all configured pools
     */
    getPools(): PoolConfig[] {
        const config = this.getConfig();
        return config.pools;
    }

    /**
     * Get token information by symbol
     */
    getToken(symbol: string): TokenInfo {
        const config = this.getConfig();
        if (!config.tokens[symbol]) {
            throw new Error(`Token ${symbol} not found in configuration`);
        }
        return config.tokens[symbol];
    }

    /**
     * Get all token symbols
     */
    getAllTokenSymbols(): string[] {
        const config = this.getConfig();
        return Object.keys(config.tokens);
    }

    /**
     * Get Uniswap V3 contract addresses
     */
    getUniswapV3Contracts(): UniswapV3Contracts {
        const config = this.getConfig();
        return config.uniswapV3;
    }

    /**
     * Get target liquidity in USD
     */
    getLiquidityUsd(): number {
        const config = this.getConfig();
        return config.liquidityUsd;
    }

    /**
     * Get CoinGecko mapping (symbol to CoinGecko ID)
     */
    getCoinGeckoMapping(): Record<string, string> {
        const config = this.getConfig();
        return config.coinGeckoMapping;
    }

    /**
     * Get all tokens as a record
     */
    getTokens(): Record<string, TokenInfo> {
        const config = this.getConfig();
        return config.tokens;
    }

    /**
     * Get Uniswap V3 contract addresses (alias for getUniswapV3Contracts)
     */
    getUniswapV3Addresses(): UniswapV3Contracts {
        return this.getUniswapV3Contracts();
    }

    /**
     * Validate configuration structure
     */
    private validateConfig(config: AppConfig): void {
        // Check required top-level fields
        if (
            !config.tokens ||
            !config.pools ||
            !config.uniswapV3 ||
            typeof config.liquidityUsd !== "number" ||
            !config.coinGeckoMapping
        ) {
            throw new Error(
                "Invalid configuration: missing required fields (tokens, pools, uniswapV3, liquidityUsd, coinGeckoMapping)",
            );
        }

        // Validate tokens
        if (
            typeof config.tokens !== "object" ||
            Object.keys(config.tokens).length === 0
        ) {
            throw new Error("Configuration must contain at least one token");
        }

        Object.entries(config.tokens).forEach(([symbol, token]) => {
            if (
                !token.address ||
                typeof token.decimals !== "number" ||
                !token.symbol
            ) {
                throw new Error(
                    `Invalid token ${symbol}: missing address, decimals, or symbol`,
                );
            }
        });

        // Validate pools
        if (!Array.isArray(config.pools) || config.pools.length === 0) {
            throw new Error("Configuration must contain at least one pool");
        }

        config.pools.forEach((pool, index) => {
            if (!pool.base || !pool.quote || typeof pool.feeTier !== "number") {
                throw new Error(
                    `Invalid pool at index ${index}: missing base, quote, or feeTier`,
                );
            }

            // Validate that base and quote tokens exist
            if (!config.tokens[pool.base]) {
                throw new Error(
                    `Pool ${index}: base token ${pool.base} not found in tokens`,
                );
            }
            if (!config.tokens[pool.quote]) {
                throw new Error(
                    `Pool ${index}: quote token ${pool.quote} not found in tokens`,
                );
            }
        });

        // Validate Uniswap V3 contracts
        const required = [
            "factory",
            "positionManager",
            "swapRouter",
            "viewQuoter",
        ];
        required.forEach((field) => {
            if (!config.uniswapV3[field as keyof UniswapV3Contracts]) {
                throw new Error(
                    `Missing Uniswap V3 contract address: ${field}`,
                );
            }
        });

        logger.info("Configuration validation passed");
    }

    /**
     * Reload configuration from file
     */
    async reloadConfig(): Promise<AppConfig> {
        logger.info("Reloading configuration...");
        this.config = null;
        return await this.loadConfig();
    }

    /**
     * Get configuration file path
     */
    getConfigPath(): string {
        return this.configPath;
    }
}
