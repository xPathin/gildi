import dotenv from "dotenv";
import { logger } from "./utils/logger";
import { config } from "./config/config";
import { AppService } from "./services/appService";

// Load environment variables
dotenv.config();

// Global service instance
let appService: AppService;

async function main(): Promise<void> {
    try {
        logger.info("Starting Uniswap V3 Price Mirror");
        logger.info("");

        // Log basic configuration
        logger.info(`Environment: ${config.nodeEnv}`);
        logger.info(`Network: Optimism Sepolia (${config.chainId})`);
        logger.info(`Log Level: ${config.logLevel}`);

        // Validate configuration
        await validateConfiguration();

        // Initialize app service
        logger.info("Initializing App Service...");
        appService = new AppService();

        // Setup graceful shutdown handlers
        process.on("SIGINT", gracefulShutdown);
        process.on("SIGTERM", gracefulShutdown);

        // Start the app service
        await appService.start();

        logger.info("Application started successfully");
        logger.info("Press Ctrl+C to stop the application");

        // Keep the process running
        await new Promise(() => {}); // Run indefinitely
    } catch (error) {
        logger.error("Failed to start application:", error);
        process.exit(1);
    }
}

async function validateConfiguration(): Promise<void> {
    logger.info("Validating configuration...");

    // Check required environment variables
    const requiredVars = ["PRIVATE_KEY", "RPC_URL", "CHAIN_ID"];

    const missingVars = requiredVars.filter((varName) => !process.env[varName]);

    if (missingVars.length > 0) {
        logger.error("Missing required environment variables:");
        missingVars.forEach((varName) => {
            logger.error(`   - ${varName}`);
        });
        logger.error(
            "Please check your .env file and ensure all required variables are set",
        );
        throw new Error("Missing required environment variables");
    }

    // Validate private key format
    if (
        !config.privateKey.startsWith("0x") ||
        config.privateKey.length !== 66
    ) {
        logger.warn(
            "Private key should be a 64-character hex string starting with 0x",
        );
    }

    // Validate chain ID
    if (config.chainId !== 11155420) {
        logger.warn(
            "Chain ID is not Optimism Sepolia (11155420). Make sure this is intentional.",
        );
    }

    // Validate intervals
    if (config.priceUpdateIntervalMinutes < 1) {
        logger.error("Price update interval must be at least 1 minute");
        throw new Error("Invalid price update interval");
    }

    // Validate liquidity amount
    if (config.liquidityUsd <= 0) {
        logger.error("Liquidity USD amount must be positive");
        throw new Error("Invalid liquidity amount");
    }

    logger.info("Configuration validated successfully");
}

function gracefulShutdown(signal: string): void {
    logger.info(`Received ${signal}. Shutting down gracefully...`);

    if (appService && appService.getIsRunning()) {
        logger.info("Stopping app service...");
        appService.stop();
    }

    logger.info("Goodbye!");
    process.exit(0);
}

// Handle uncaught exceptions
process.on("uncaughtException", (error: Error) => {
    logger.error("Uncaught Exception:", error);

    if (appService && appService.getIsRunning()) {
        appService.stop();
    }

    process.exit(1);
});

process.on(
    "unhandledRejection",
    (reason: unknown, promise: Promise<unknown>) => {
        logger.error("Unhandled Rejection at:", promise, "reason:", reason);

        if (appService && appService.getIsRunning()) {
            appService.stop();
        }

        process.exit(1);
    },
);

// Start the application
if (require.main === module) {
    main().catch((error) => {
        logger.error("Application failed to start:", error);
        process.exit(1);
    });
}

export { main };
