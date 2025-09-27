import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

interface Config {
  nodeEnv: string;
  port: number;
  apiUrl: string;
  databaseUrl?: string;
  logLevel: string;
  corsOrigin: string;
  // Blockchain configuration
  rpcUrl: string;
  chainId: number;
  privateKey: string;
  // Price fetching configuration
  coingeckoApiKey?: string;
  priceUpdateIntervalMinutes: number;
  // Uniswap V3 addresses for Optimism Sepolia
  uniswapV3Factory: string;
  uniswapV3PositionManager: string;
  uniswapV3SwapRouter: string;
  uniswapV3ViewQuoter: string;
  // Liquidity management
  liquidityUsd: number;
}

function validateConfig(): Config {
  const nodeEnv = process.env['NODE_ENV'] || 'development';
  const port = parseInt(process.env['PORT'] || '3000', 10);
  const apiUrl = process.env['API_URL'] || 'http://localhost:3000';
  const databaseUrl = process.env['DATABASE_URL'];
  const logLevel = process.env['LOG_LEVEL'] || 'info';
  const corsOrigin = process.env['CORS_ORIGIN'] || '*';

  // Blockchain configuration
  const rpcUrl = process.env['RPC_URL'] || 'https://sepolia.optimism.io';
  const chainId = parseInt(process.env['CHAIN_ID'] || '11155420', 10);
  const privateKey = process.env['PRIVATE_KEY'] || '';

  // Price fetching configuration
  const coingeckoApiKey = process.env['COINGECKO_API_KEY'];
  const priceUpdateIntervalMinutes = parseInt(process.env['PRICE_UPDATE_INTERVAL_MINUTES'] || '5', 10);

  // Uniswap V3 addresses for Optimism Sepolia
  const uniswapV3Factory = process.env['UNISWAP_V3_FACTORY'] || '0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24';
  const uniswapV3PositionManager = process.env['UNISWAP_V3_POSITION_MANAGER'] || '0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2';
  const uniswapV3SwapRouter = process.env['UNISWAP_V3_SWAP_ROUTER'] || '0x101F443B4d1b059569D643917553c771E1b9663E';
  const uniswapV3ViewQuoter = process.env['UNISWAP_V3_VIEW_QUOTER'] || '0x209e0EC7a5AA843B3Fc04e882Dd7a7d4e0Aae3e7';

  // Liquidity management
  const liquidityUsd = parseFloat(process.env['LIQUIDITY_USD'] || '10000');

  // Validate required environment variables
  if (isNaN(port)) {
    throw new Error('PORT must be a valid number');
  }

  if (isNaN(chainId)) {
    throw new Error('CHAIN_ID must be a valid number');
  }

  if (!privateKey) {
    throw new Error('PRIVATE_KEY is required');
  }

  if (isNaN(priceUpdateIntervalMinutes) || priceUpdateIntervalMinutes < 1) {
    throw new Error('PRICE_UPDATE_INTERVAL_MINUTES must be a valid number >= 1');
  }

  if (isNaN(liquidityUsd) || liquidityUsd <= 0) {
    throw new Error('LIQUIDITY_USD must be a valid positive number');
  }

  const config: Config = {
    nodeEnv,
    port,
    apiUrl,
    logLevel,
    corsOrigin,
    rpcUrl,
    chainId,
    privateKey,
    priceUpdateIntervalMinutes,
    uniswapV3Factory,
    uniswapV3PositionManager,
    uniswapV3SwapRouter,
    uniswapV3ViewQuoter,
    liquidityUsd,
  };

  if (databaseUrl) {
    config.databaseUrl = databaseUrl;
  }

  if (coingeckoApiKey) {
    config.coingeckoApiKey = coingeckoApiKey;
  }

  return config;
}

export const config = validateConfig();
