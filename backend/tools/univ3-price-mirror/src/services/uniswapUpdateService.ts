import { ethers } from "ethers";
import { logger } from "../utils/logger";
import {
    TickMath,
    nearestUsableTick,
    TICK_SPACINGS,
    FeeAmount,
    encodeSqrtRatioX96,
} from "@uniswap/v3-sdk";
import {
    IUniswapV3Factory__factory,
    INonfungiblePositionManager__factory,
    IUniswapV3Pool__factory,
    MockERC20MintableOwnable__factory,
    IUniswapV3SwapRouter02__factory,
    IUniswapV3ViewQuoterV1__factory,
} from "../typechain-types";

// ============================================================================
// Type Definitions
// ============================================================================

export interface TokenConfig {
    address: string;
    decimals: number;
    symbol: string;
}

export interface PairConfig {
    base: string;
    quote: string;
    feeTier: number;
}

export interface UniswapV3Addresses {
    factory: string;
    positionManager: string;
    swapRouter: string;
    viewQuoter: string;
}

export interface UniswapUpdateConfig {
    tokens: Record<string, TokenConfig>;
    prices: Record<string, number>;
    pools: PairConfig[];
    liquidityUsd: number;
    uniswapV3: UniswapV3Addresses;
}

export interface UniswapUpdateResult {
    success: boolean;
    poolsProcessed: number;
    errors?: string[];
    transactionHashes?: string[];
}

// ============================================================================
// Core Helper Functions
// ============================================================================

/**
 * @dev Calculate sqrt price using the SDK's TickMath - most reliable approach
 * @param _targetPrice Target price as number (already adjusted for token semantics)
 * @param _decimals0 Token0 decimals
 * @param _decimals1 Token1 decimals
 */
function _calculateSqrtPriceX96(
    _targetPrice: number,
    _decimals0: number,
    _decimals1: number,
): bigint {
    // Convert price to tick first, then get sqrtPrice from tick
    // This uses the battle-tested SDK functions

    // The target price passed in is the economic ratio (token1/token0)
    // We need to convert this to the raw token units ratio for the pool
    // Formula: rawRatio = economicRatio * (10^decimals1 / 10^decimals0)
    // Which simplifies to: rawRatio = economicRatio * 10^(decimals1 - decimals0)

    const decimalAdjustment = _decimals1 - _decimals0;
    const adjustmentMultiplier = Math.pow(10, decimalAdjustment);
    const adjustedPrice = _targetPrice * adjustmentMultiplier;

    // Prevent extreme price calculations
    const safePrice = Math.max(Math.min(adjustedPrice, 1e12), 1e-12);
    const tick = Math.floor(Math.log(safePrice) / Math.log(1.0001));

    // Clamp to Uniswap's absolute tick bounds (±887272)
    const clampedTick = Math.max(
        TickMath.MIN_TICK,
        Math.min(TickMath.MAX_TICK, tick),
    );

    // Use SDK to get precise sqrtPriceX96 from tick
    const sqrtPriceX96 = TickMath.getSqrtRatioAtTick(clampedTick);

    logger.info(
        `SqrtPrice result: tick=${clampedTick}, sqrtPriceX96=${sqrtPriceX96.toString()}`,
    );

    return BigInt(sqrtPriceX96.toString());
}

/**
 * @dev Get pool's current state
 * @param _poolAddress Pool address
 * @param _signer Signer for contract calls
 */
async function _getPoolCurrentState(
    _poolAddress: string,
    _signer: ethers.Signer,
): Promise<{
    tick: number;
    sqrtPriceX96: bigint;
    liquidity: bigint;
    token0: string;
    token1: string;
    fee: number;
}> {
    const poolContract = IUniswapV3Pool__factory.connect(_poolAddress, _signer);

    const [slot0, liquidity, token0, token1, fee] = await Promise.all([
        poolContract.slot0(),
        poolContract.liquidity(),
        poolContract.token0(),
        poolContract.token1(),
        poolContract.fee(),
    ]);

    return {
        tick: Number(slot0.tick),
        sqrtPriceX96: BigInt(slot0.sqrtPriceX96.toString()),
        liquidity: BigInt(liquidity.toString()),
        token0: token0.toLowerCase(),
        token1: token1.toLowerCase(),
        fee: Number(fee),
    };
}

// ============================================================================
// Uniswap Update Service
// ============================================================================

export class UniswapUpdateService {
    private signer: ethers.Wallet;
    private config: UniswapUpdateConfig | null = null;

    constructor(signer: ethers.Wallet) {
        this.signer = signer;
        logger.info("UniswapUpdateService initialized");
    }

    /**
     * @dev Calculate USD value of liquidity in a specific tick range
     * @param _poolAddress Pool address
     * @param _tickLower Lower tick of range
     * @param _tickUpper Upper tick of range
     * @param _config Configuration
     * @param _signer Signer for transactions
     */
    async _calculateLiquidityUSDInRange(
        _poolAddress: string,
        _tickLower: number,
        _tickUpper: number,
        _config: UniswapUpdateConfig,
    ): Promise<number> {
        try {
            const poolState = await _getPoolCurrentState(
                _poolAddress,
                this.signer,
            );

            // Get token configs
            let token0Config: TokenConfig | undefined;
            let token1Config: TokenConfig | undefined;

            for (const tokenConfig of Object.values(_config.tokens)) {
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token0.toLowerCase()
                ) {
                    token0Config = tokenConfig;
                }
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token1.toLowerCase()
                ) {
                    token1Config = tokenConfig;
                }
            }

            if (!token0Config || !token1Config) {
                throw new Error("Token configs not found");
            }

            // If current tick is outside the range, liquidity is 0
            if (poolState.tick < _tickLower || poolState.tick > _tickUpper) {
                return 0;
            }

            // Use Uniswap math to calculate token amounts from liquidity
            const JSBI = require("jsbi");
            const { SqrtPriceMath } = require("@uniswap/v3-sdk");

            const currentSqrtPriceJSBI = JSBI.BigInt(
                poolState.sqrtPriceX96.toString(),
            );
            const sqrtPriceLowerJSBI = JSBI.BigInt(
                TickMath.getSqrtRatioAtTick(_tickLower).toString(),
            );
            const sqrtPriceUpperJSBI = JSBI.BigInt(
                TickMath.getSqrtRatioAtTick(_tickUpper).toString(),
            );
            const liquidityJSBI = JSBI.BigInt(poolState.liquidity.toString());

            // Calculate token amounts in the range
            const amount0JSBI = SqrtPriceMath.getAmount0Delta(
                currentSqrtPriceJSBI,
                sqrtPriceUpperJSBI,
                liquidityJSBI,
                false,
            );

            const amount1JSBI = SqrtPriceMath.getAmount1Delta(
                sqrtPriceLowerJSBI,
                currentSqrtPriceJSBI,
                liquidityJSBI,
                false,
            );

            // Convert to native BigInt and then to readable amounts
            const amount0 = BigInt(amount0JSBI.toString());
            const amount1 = BigInt(amount1JSBI.toString());

            const amount0Readable = parseFloat(
                ethers.formatUnits(amount0, token0Config.decimals),
            );
            const amount1Readable = parseFloat(
                ethers.formatUnits(amount1, token1Config.decimals),
            );

            const token0Price = _config.prices[token0Config.symbol];
            const token1Price = _config.prices[token1Config.symbol];

            if (!token0Price || !token1Price) {
                logger.error("Token prices not found");
                return 0;
            }

            // Calculate USD value
            const usdValue0 = amount0Readable * token0Price;
            const usdValue1 = amount1Readable * token1Price;

            return usdValue0 + usdValue1;
        } catch (error) {
            console.warn(
                `Failed to calculate USD value in range [${_tickLower}, ${_tickUpper}]:`,
                error,
            );
            return 0;
        }
    }

    /**
     * Add bootstrap full-range liquidity to ensure swaps don't fail during initial moves
     * @dev Exact implementation from reference - uses mock tokens for minting
     * @param _poolAddress Pool address
     * @param _config Configuration
     * @returns Success status
     */
    private async _addBootstrapFullRangeLiquidity(
        _poolAddress: string,
        _config: UniswapUpdateConfig,
    ): Promise<boolean> {
        try {
            const poolState = await _getPoolCurrentState(
                _poolAddress,
                this.signer,
            );

            // Only add bootstrap full-range liquidity if the pool has no active liquidity yet
            if (poolState.liquidity > BigInt(0)) {
                logger.info(
                    "Skipping bootstrap full-range liquidity: pool already has liquidity",
                );
                return true;
            }

            // Get token configs
            let token0Config: any | undefined;
            let token1Config: any | undefined;

            for (const tokenConfig of Object.values(_config.tokens)) {
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token0.toLowerCase()
                ) {
                    token0Config = tokenConfig;
                }
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token1.toLowerCase()
                ) {
                    token1Config = tokenConfig;
                }
            }

            if (!token0Config || !token1Config) {
                throw new Error("Token configs not found");
            }

            const tickSpacing = TICK_SPACINGS[poolState.fee as FeeAmount];

            // Create bootstrap full-range liquidity to prevent any swap failures
            const bootstrapRange = 600000; // Huge range
            const tickLower = nearestUsableTick(-bootstrapRange, tickSpacing);
            const tickUpper = nearestUsableTick(bootstrapRange, tickSpacing);

            logger.info(
                `Adding bootstrap full-range liquidity: [${tickLower}, ${tickUpper}]`,
            );

            // Determine per-token USD bootstrap amount (configurable)
            const bootstrapUsdPerToken = _config.liquidityUsd;
            if (bootstrapUsdPerToken <= 0) {
                logger.info(
                    "Skipping bootstrap full-range liquidity per config (0)",
                );
                return true;
            }
            const token0Price = _config.prices[token0Config.symbol];
            const token1Price = _config.prices[token1Config.symbol];

            if (!token0Price || !token1Price) {
                throw new Error(
                    `Missing prices for bootstrap: ${token0Config.symbol} or ${token1Config.symbol}`,
                );
            }

            const token0Amount = bootstrapUsdPerToken / token0Price;
            const token1Amount = bootstrapUsdPerToken / token1Price;

            const amount0Desired = ethers.parseUnits(
                token0Amount.toFixed(token0Config.decimals),
                token0Config.decimals,
            );
            const amount1Desired = ethers.parseUnits(
                token1Amount.toFixed(token1Config.decimals),
                token1Config.decimals,
            );

            // Mint enormous amounts (MOCK TOKENS)
            const signerAddress = await this.signer.getAddress();
            const token0Contract = MockERC20MintableOwnable__factory.connect(
                poolState.token0,
                this.signer,
            );
            const token1Contract = MockERC20MintableOwnable__factory.connect(
                poolState.token1,
                this.signer,
            );

            logger.info(
                `Minting bootstrap amounts: ${ethers.formatUnits(
                    amount0Desired,
                    token0Config.decimals,
                )} ${token0Config.symbol} + ${ethers.formatUnits(
                    amount1Desired,
                    token1Config.decimals,
                )} ${token1Config.symbol}`,
            );

            // Wait for each transaction to be confirmed to avoid nonce issues
            const mint0Tx = await token0Contract.mint(
                signerAddress,
                amount0Desired,
            );
            await mint0Tx.wait();

            const mint1Tx = await token1Contract.mint(
                signerAddress,
                amount1Desired,
            );
            await mint1Tx.wait();

            // Approve enormous amounts
            const approve0Tx = await token0Contract.approve(
                _config.uniswapV3.positionManager,
                amount0Desired,
            );
            await approve0Tx.wait();

            const approve1Tx = await token1Contract.approve(
                _config.uniswapV3.positionManager,
                amount1Desired,
            );
            await approve1Tx.wait();

            // Add the bootstrap liquidity
            const positionManager =
                INonfungiblePositionManager__factory.connect(
                    _config.uniswapV3.positionManager,
                    this.signer,
                );
            const deadline = Math.floor(Date.now() / 1000) + 300;

            const mintParams = {
                token0: poolState.token0,
                token1: poolState.token1,
                fee: poolState.fee,
                tickLower,
                tickUpper,
                amount0Desired,
                amount1Desired,
                amount0Min: BigInt(0),
                amount1Min: BigInt(0),
                recipient: signerAddress,
                deadline,
            };

            logger.info(`Minting bootstrap full-range position...`);
            const mintTx = await positionManager.mint(mintParams);
            const receipt = await mintTx.wait();

            if (receipt && receipt.status === 1) {
                logger.info(
                    `Bootstrap full-range liquidity added successfully`,
                );
                return true;
            } else {
                throw new Error("Bootstrap liquidity minting failed");
            }
        } catch (error) {
            logger.error(`Failed to add bootstrap liquidity:`, error);
            return false;
        }
    }

    /**
     * @dev Add concentrated liquidity ensuring minimum USD value in target range
     * @param _poolAddress Pool address
     * @param _liquidityUsd Target USD liquidity
     * @param _config Configuration
     * @param _signer Signer for transactions
     */
    async _addConcentratedLiquidity(
        _poolAddress: string,
        _liquidityUsd: number,
        _config: UniswapUpdateConfig,
    ): Promise<boolean> {
        try {
            // Get fresh pool state after any swaps
            const poolState = await _getPoolCurrentState(
                _poolAddress,
                this.signer,
            );
            logger.info(
                `Adding concentrated liquidity around tick ${poolState.tick}`,
            );

            // Get token configs
            let token0Config: TokenConfig | undefined;
            let token1Config: TokenConfig | undefined;

            for (const tokenConfig of Object.values(_config.tokens)) {
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token0.toLowerCase()
                ) {
                    token0Config = tokenConfig;
                }
                if (
                    tokenConfig.address.toLowerCase() ===
                    poolState.token1.toLowerCase()
                ) {
                    token1Config = tokenConfig;
                }
            }

            if (!token0Config || !token1Config) {
                throw new Error("Token configs not found");
            }

            const tickSpacing = TICK_SPACINGS[poolState.fee as FeeAmount];
            const maxValidTick = TickMath.MAX_TICK;
            const minValidTick = TickMath.MIN_TICK;

            // Create concentrated liquidity in a tight range around current price (±5% price range)
            // This corresponds to roughly ±500 ticks for most tokens
            const concentratedRange = 500;
            let tickLower = nearestUsableTick(
                Math.max(
                    poolState.tick - concentratedRange,
                    minValidTick + tickSpacing,
                ),
                tickSpacing,
            );
            let tickUpper = nearestUsableTick(
                Math.min(
                    poolState.tick + concentratedRange,
                    maxValidTick - tickSpacing,
                ),
                tickSpacing,
            );

            // Ensure valid range
            if (tickLower >= tickUpper) {
                tickLower = nearestUsableTick(
                    Math.max(poolState.tick - tickSpacing, minValidTick),
                    tickSpacing,
                );
                tickUpper = nearestUsableTick(
                    Math.min(poolState.tick + tickSpacing, maxValidTick),
                    tickSpacing,
                );
            }

            logger.info(
                `Concentrated liquidity range: [${tickLower}, ${tickUpper}] (${
                    tickUpper - tickLower
                } ticks)`,
            );

            // Heuristic: skip minting if enough active liquidity already exists in this range
            const existingUsdInRange = await this._calculateLiquidityUSDInRange(
                _poolAddress,
                tickLower,
                tickUpper,
                _config,
            );
            if (existingUsdInRange >= _liquidityUsd * 0.95) {
                logger.info(
                    `Skipping guard mint: existing active liquidity ~$${existingUsdInRange.toFixed(
                        2,
                    )} ≥ target $${_liquidityUsd}`,
                );
                return true;
            }

            // Deterministic guard liquidity: mint a single position sized to `_liquidityUsd` split 50/50 across tokens
            const token0UsdPrice = _config.prices[token0Config.symbol];
            const token1UsdPrice = _config.prices[token1Config.symbol];

            if (!token0UsdPrice || !token1UsdPrice) {
                logger.error("Token prices not found");
                return false;
            }

            const totalUsdToAdd = _liquidityUsd;
            const usdPerToken = totalUsdToAdd / 2;

            const token0Amount = usdPerToken / token0UsdPrice;
            const token1Amount = usdPerToken / token1UsdPrice;

            const amount0Desired = ethers.parseUnits(
                token0Amount.toFixed(token0Config.decimals),
                token0Config.decimals,
            );
            const amount1Desired = ethers.parseUnits(
                token1Amount.toFixed(token1Config.decimals),
                token1Config.decimals,
            );

            logger.info(
                `Amounts to add: ${ethers.formatUnits(
                    amount0Desired,
                    token0Config.decimals,
                )} ${token0Config.symbol} + ${ethers.formatUnits(
                    amount1Desired,
                    token1Config.decimals,
                )} ${token1Config.symbol}`,
            );

            // Ensure we have enough tokens - mint generously since we control everything
            const signerAddress = await this.signer.getAddress();

            const token0Contract = MockERC20MintableOwnable__factory.connect(
                poolState.token0,
                this.signer,
            );
            const token1Contract = MockERC20MintableOwnable__factory.connect(
                poolState.token1,
                this.signer,
            );

            // Check balances and mint if needed
            const balance0 = await token0Contract.balanceOf(signerAddress);
            const balance1 = await token1Contract.balanceOf(signerAddress);

            if (balance0 < amount0Desired) {
                const mintAmount0 = amount0Desired - balance0;
                logger.info(
                    `Minting ${ethers.formatUnits(
                        mintAmount0,
                        token0Config.decimals,
                    )} ${token0Config.symbol}`,
                );
                const res = await token0Contract.mint(
                    signerAddress,
                    mintAmount0,
                );
                await res.wait();
            }

            if (balance1 < amount1Desired) {
                const mintAmount1 = amount1Desired - balance1;
                logger.info(
                    `Minting ${ethers.formatUnits(
                        mintAmount1,
                        token1Config.decimals,
                    )} ${token1Config.symbol}`,
                );
                const res = await token1Contract.mint(
                    signerAddress,
                    mintAmount1,
                );
                await res.wait();
            }

            // Approve tokens generously
            const approveRes0 = await token0Contract.approve(
                _config.uniswapV3.positionManager,
                amount0Desired * BigInt(2),
            );
            await approveRes0.wait();

            const approveRes1 = await token1Contract.approve(
                _config.uniswapV3.positionManager,
                amount1Desired * BigInt(2),
            );
            await approveRes1.wait();

            // Add concentrated liquidity
            const positionManager =
                INonfungiblePositionManager__factory.connect(
                    _config.uniswapV3.positionManager,
                    this.signer,
                );
            const deadline = Math.floor(Date.now() / 1000) + 300;

            const mintParams = {
                token0: poolState.token0,
                token1: poolState.token1,
                fee: poolState.fee,
                tickLower,
                tickUpper,
                amount0Desired,
                amount1Desired,
                amount0Min: BigInt(0), // Accept any ratio - we control the pool
                amount1Min: BigInt(0),
                recipient: signerAddress,
                deadline,
            };

            logger.info(`Minting liquidity position...`);
            const mintTx = await positionManager.mint(mintParams);
            const receipt = await mintTx.wait();
            if (!receipt || receipt.status !== 1) {
                throw new Error("Liquidity minting failed");
            }
            logger.info("Guard liquidity minted");
            return true;
        } catch (error) {
            console.error(`Failed to add liquidity: ${error}`);
            return false;
        }
    }

    /**
     * Market sanity quote validator to check fair pricing using exact-input
     * @dev EXACT implementation from reference
     * @param _poolAddress Pool address
     * @param _baseSymbol Base token symbol
     * @param _quoteSymbol Quote token symbol
     * @param _fee Pool fee
     * @param _config Configuration
     */
    private async _printMarketSanityQuoteOneBase(
        _poolAddress: string,
        _baseSymbol: string,
        _quoteSymbol: string,
        _fee: number,
        _config: UniswapUpdateConfig,
    ): Promise<void> {
        try {
            const baseCfg = _config.tokens[_baseSymbol];
            const quoteCfg = _config.tokens[_quoteSymbol];
            if (!baseCfg || !quoteCfg) {
                logger.warn(
                    `Market sanity check skipped: token config missing for ${_baseSymbol}/${_quoteSymbol}`,
                );
                return;
            }

            // Get the actual pool state to verify token ordering
            const poolState = await _getPoolCurrentState(
                _poolAddress,
                this.signer,
            );

            // Verify that we're using the correct pool
            const poolHasBase =
                poolState.token0.toLowerCase() ===
                    baseCfg.address.toLowerCase() ||
                poolState.token1.toLowerCase() ===
                    baseCfg.address.toLowerCase();
            const poolHasQuote =
                poolState.token0.toLowerCase() ===
                    quoteCfg.address.toLowerCase() ||
                poolState.token1.toLowerCase() ===
                    quoteCfg.address.toLowerCase();

            if (!poolHasBase || !poolHasQuote) {
                logger.warn(
                    `Market sanity check failed: pool token mismatch. Pool has tokens [${poolState.token0}, ${poolState.token1}], expected [${baseCfg.address}, ${quoteCfg.address}]`,
                );
                return;
            }

            const quoter = IUniswapV3ViewQuoterV1__factory.connect(
                _config.uniswapV3.viewQuoter,
                this.signer,
            );

            // Use $1 USD equivalent of base token for sanity check to avoid liquidity constraints
            const baseTokenUsdPrice = _config.prices[_baseSymbol];
            if (!baseTokenUsdPrice) {
                logger.warn(`Missing price for ${_baseSymbol} in sanity check`);
                return;
            }

            const usdAmountToTest = 1.0; // Test with $1 USD worth
            const baseTokenAmountToTest = usdAmountToTest / baseTokenUsdPrice;
            let requestedAmount = ethers.parseUnits(
                baseTokenAmountToTest.toFixed(baseCfg.decimals),
                baseCfg.decimals,
            );
            if (requestedAmount === 0n && baseTokenAmountToTest > 0) {
                // Avoid zero-amount exact-output quote due to rounding of tiny amounts
                requestedAmount = 1n;
            }
            const quote = await quoter.quoteExactOutputSingleWithPool({
                tokenIn: quoteCfg.address,
                tokenOut: baseCfg.address,
                amount: requestedAmount,
                pool: _poolAddress,
                fee: _fee,
                sqrtPriceLimitX96: 0,
            });

            const quoteCost = ethers.formatUnits(
                quote.amountIn,
                quoteCfg.decimals,
            );

            // Calculate expected cost using SAME logic as pool targeting (accounting for token ordering)
            // Sort tokens by address to match pool logic
            const [token0, token1] =
                baseCfg.address.toLowerCase() < quoteCfg.address.toLowerCase()
                    ? [baseCfg, quoteCfg]
                    : [quoteCfg, baseCfg];

            const basePrice = _config.prices[_baseSymbol];
            const quotePrice = _config.prices[_quoteSymbol];

            if (!basePrice || !quotePrice) {
                logger.warn(
                    `Missing prices for ${_baseSymbol} or ${_quoteSymbol} in sanity check`,
                );
                return;
            }

            // Token ordering validation (keeping logic consistent with main execution)
            if (
                token0.symbol === _baseSymbol &&
                token1.symbol === _quoteSymbol
            ) {
                // Pool ordering: base as token0, quote as token1
            } else if (
                token0.symbol === _quoteSymbol &&
                token1.symbol === _baseSymbol
            ) {
                // Pool ordering: quote as token0, base as token1
            } else {
                logger.warn(
                    `Unexpected token ordering in sanity check: token0=${token0.symbol}, token1=${token1.symbol}, base=${_baseSymbol}, quote=${_quoteSymbol}`,
                );
            }

            // Show both USD-based validation and scaled full-token price for user intuition
            const actualQuoteCostPerDollar = Number(quoteCost);
            const quotePriceUsd = _config.prices[_quoteSymbol];
            const basePriceUsd = _config.prices[_baseSymbol];

            if (!quotePriceUsd || !basePriceUsd) {
                logger.warn(`Missing USD prices for calculation`);
                return;
            }

            // Include pool fee in the expected prices (exact-output quotes include input-side fee)
            const feeRate = _fee / 1_000_000; // e.g., 3000 => 0.003
            const feeAdj = 1 / (1 - feeRate); // adjust expected input by 1/(1 - fee)
            const expectedQuoteCostPerDollar =
                (usdAmountToTest / quotePriceUsd) * feeAdj; // $1 worth of quote token incl fee

            // Scale to show full token price (more intuitive for users)
            const scaleFactor = 1 / baseTokenAmountToTest; // scale from test amount to 1 full token
            const actualFullTokenPrice = actualQuoteCostPerDollar * scaleFactor;
            const expectedFullTokenPrice =
                (basePriceUsd / quotePriceUsd) * feeAdj;

            logger.info(`Sanity Market Check:`);
            logger.info(
                `   ${actualFullTokenPrice.toFixed(8)} ${quoteCfg.symbol} for 1 ${
                    baseCfg.symbol
                } (expected ~${expectedFullTokenPrice.toFixed(8)} incl fee ${(
                    feeRate * 100
                ).toFixed(2)}%)`,
            );
            logger.info(
                `   ${actualQuoteCostPerDollar.toFixed(8)} ${
                    quoteCfg.symbol
                } for $${usdAmountToTest} of ${
                    baseCfg.symbol
                } (expected ~${expectedQuoteCostPerDollar.toFixed(8)} incl fee ${(
                    feeRate * 100
                ).toFixed(2)}%)`,
            );

            // Additional validation: check if the quote is reasonable using high-precision arithmetic
            const actualQuoteCostBigInt = quote.amountIn;
            const expectedQuoteCostBigInt = ethers.parseUnits(
                expectedQuoteCostPerDollar.toFixed(quoteCfg.decimals),
                quoteCfg.decimals,
            );

            const priceDiffBigInt =
                actualQuoteCostBigInt > expectedQuoteCostBigInt
                    ? actualQuoteCostBigInt - expectedQuoteCostBigInt
                    : expectedQuoteCostBigInt - actualQuoteCostBigInt;

            // Compute deviation in basis points (bps) using BigInt to avoid precision loss
            const deviationBps =
                expectedQuoteCostBigInt > 0n
                    ? (priceDiffBigInt * 10_000n) / expectedQuoteCostBigInt
                    : 0n;

            // Format percent string without BigInt->Number conversion
            const percentInteger = deviationBps / 100n;
            const percentFraction = (deviationBps % 100n)
                .toString()
                .padStart(2, "0");
            const percentStr = `${percentInteger}.${percentFraction}`;

            if (deviationBps == 0n) {
                logger.info(`New price spot on!`);
            } else if (deviationBps < 1_00n) {
                logger.info(
                    `Slight price deviation: ${percentStr}% difference from expected price`,
                );
            } else {
                logger.warn(
                    `Large Price deviation: ${percentStr}% difference from expected price`,
                );
            }
        } catch (error) {
            logger.warn(`Market sanity check failed: ${error}`);
        }
    }

    /**
     * Precise swap to exact target tick using Uniswap V3 math (with pre-swap liquidity)
     * @dev EXACT implementation from reference - uses mock tokens
     * @param _poolAddress Pool address
     * @param _targetTick Target tick
     * @param _config Configuration
     * @returns Success status
     */
    private async _preciseSwapToTarget(
        _poolAddress: string,
        _targetTick: number,
        _config: UniswapUpdateConfig,
    ): Promise<boolean> {
        try {
            const poolState = await _getPoolCurrentState(
                _poolAddress,
                this.signer,
            );

            logger.info(
                `Precise swap: Current tick ${poolState.tick} → Target tick ${_targetTick}`,
            );

            // Accept very tight deviations for <1% precision target
            if (Math.abs(poolState.tick - _targetTick) <= 5) {
                logger.info(`Already close to target (within 5 ticks)`);
                return true;
            }

            // Calculate target sqrtPrice and set a price limit so we cannot overshoot
            const targetSqrtPriceX96 = TickMath.getSqrtRatioAtTick(_targetTick);

            // Determine swap direction
            const zeroForOne = _targetTick < poolState.tick;
            const tokenInAddress = zeroForOne
                ? poolState.token0
                : poolState.token1;
            const tokenOutAddress = zeroForOne
                ? poolState.token1
                : poolState.token0;

            // Get token configs
            let tokenInConfig: any | undefined;
            let tokenOutConfig: any | undefined;

            for (const tokenConfig of Object.values(_config.tokens)) {
                if (
                    tokenConfig.address.toLowerCase() ===
                    tokenInAddress.toLowerCase()
                ) {
                    tokenInConfig = tokenConfig;
                }
                if (
                    tokenConfig.address.toLowerCase() ===
                    tokenOutAddress.toLowerCase()
                ) {
                    tokenOutConfig = tokenConfig;
                }
            }

            if (!tokenInConfig || !tokenOutConfig) {
                throw new Error("Token configs not found for swap calculation");
            }

            logger.info(
                `Swap direction: ${
                    zeroForOne ? "token0→token1" : "token1→token0"
                } (${tokenInConfig.symbol}→${tokenOutConfig.symbol})`,
            );

            const priceLimitX96 = BigInt(targetSqrtPriceX96.toString());
            const tokenInContract = MockERC20MintableOwnable__factory.connect(
                tokenInAddress,
                this.signer,
            );
            const signerAddress = await this.signer.getAddress();
            const swapRouter = IUniswapV3SwapRouter02__factory.connect(
                _config.uniswapV3.swapRouter,
                this.signer,
            );

            // Start with a liquidity-aware estimate then exponentially increase until we hit the limit (target)
            let attempt = 0;
            const maxAttempts = 20; // allow more attempts for extreme deviations
            const toleranceTicks = 5; // aim for <1% precision (5 ticks ≈ 0.05%)

            // Start from a sane USD floor (configurable) and optionally cap per-attempt USD exposure
            const minSwapUsd = _config.liquidityUsd || 1000;
            const maxSwapUsdCap = Number.POSITIVE_INFINITY;
            const tokenInPrice = _config.prices[tokenInConfig.symbol];

            if (!tokenInPrice) {
                throw new Error(`Missing price for ${tokenInConfig.symbol}`);
            }

            const startUsd = Math.min(minSwapUsd, maxSwapUsdCap);
            const toAmountIn = (usd: number) =>
                ethers.parseUnits(
                    (usd / tokenInPrice).toFixed(tokenInConfig.decimals),
                    tokenInConfig.decimals,
                );
            let amountIn = toAmountIn(startUsd);

            while (attempt < maxAttempts) {
                const before = await _getPoolCurrentState(
                    _poolAddress,
                    this.signer,
                );
                const tickDiff = Math.abs(before.tick - _targetTick);
                if (tickDiff <= toleranceTicks) {
                    logger.info(
                        `Already within tolerance (${tickDiff} ticks). No further swap needed.`,
                    );
                    return true;
                }

                // Ensure balance and allowance (MINT MOCK TOKENS)
                const balance = await tokenInContract.balanceOf(signerAddress);
                if (balance < amountIn) {
                    const mintAmount = amountIn - balance;
                    logger.info(
                        `Minting ${ethers.formatUnits(
                            mintAmount,
                            tokenInConfig.decimals,
                        )} ${tokenInConfig.symbol} for swap attempt #${attempt + 1}`,
                    );
                    const mintTx = await tokenInContract.mint(
                        signerAddress,
                        mintAmount,
                    );
                    await mintTx.wait();
                }
                const approveTx = await tokenInContract.approve(
                    _config.uniswapV3.swapRouter,
                    amountIn,
                );
                await approveTx.wait();
                const approxUsd =
                    Number(
                        ethers.formatUnits(amountIn, tokenInConfig.decimals),
                    ) * tokenInPrice;
                logger.info(
                    `Attempt #${attempt + 1}: providing up to ${ethers.formatUnits(
                        amountIn,
                        tokenInConfig.decimals,
                    )} ${tokenInConfig.symbol} (~$${approxUsd.toFixed(
                        2,
                    )}) with price limit to target tick...`,
                );

                const params = {
                    tokenIn: tokenInAddress,
                    tokenOut: tokenOutAddress,
                    fee: before.fee,
                    recipient: signerAddress,
                    amountIn,
                    amountOutMinimum: BigInt(0),
                    sqrtPriceLimitX96: priceLimitX96, // prevent overshoot
                };

                try {
                    const swapTx = await swapRouter.exactInputSingle(params);
                    await swapTx.wait();

                    const after = await _getPoolCurrentState(
                        _poolAddress,
                        this.signer,
                    );
                    const newDiff = Math.abs(after.tick - _targetTick);
                    logger.info(
                        `Post-swap tick: ${after.tick}, target: ${_targetTick}, diff: ${newDiff}`,
                    );

                    if (newDiff <= toleranceTicks) {
                        logger.info(`Precise swap completed successfully!`);
                        return true;
                    }

                    // Exponentially increase amount for next attempt
                    amountIn = amountIn * BigInt(2);
                    attempt++;
                } catch (swapError) {
                    logger.warn(
                        `Swap attempt #${attempt + 1} failed: ${swapError}`,
                    );
                    amountIn = amountIn * BigInt(2);
                    attempt++;
                }
            }

            logger.error(
                `Failed to reach target tick after ${maxAttempts} attempts`,
            );
            return false;
        } catch (error) {
            logger.error(`Failed to execute precise swap:`, error);
            return false;
        }
    }

    /**
     * Execute the on-chain price updates using Uniswap V3 logic
     */
    async executeUpdate(
        config: UniswapUpdateConfig,
    ): Promise<UniswapUpdateResult> {
        logger.info("executeUpdate called - performing on-chain updates...");

        const results: UniswapUpdateResult = {
            success: true,
            poolsProcessed: 0,
            errors: [],
            transactionHashes: [],
        };

        try {
            // Initialize Uniswap V3 contracts
            const factory = IUniswapV3Factory__factory.connect(
                config.uniswapV3.factory,
                this.signer,
            );
            const manager = INonfungiblePositionManager__factory.connect(
                config.uniswapV3.positionManager,
                this.signer,
            );

            logger.info("Initialized Uniswap V3 contracts");

            // Process each pool
            for (const { base, quote, feeTier } of config.pools) {
                const pairKey = `${base}:${quote}`;
                logger.info(`\n=== Setting up ${pairKey} pool ===`);

                try {
                    // Get token configs
                    const baseToken = config.tokens[base];
                    const quoteToken = config.tokens[quote];

                    if (!baseToken || !quoteToken) {
                        throw new Error(
                            `Token config not found for ${base} or ${quote}`,
                        );
                    }

                    // Sort tokens by address (Uniswap convention)
                    const [token0, token1] =
                        baseToken.address.toLowerCase() <
                        quoteToken.address.toLowerCase()
                            ? [baseToken, quoteToken]
                            : [quoteToken, baseToken];

                    // Calculate target price for Uniswap V3 pool
                    const basePrice = config.prices[base];
                    const quotePrice = config.prices[quote];

                    // Fail-fast validation should ensure these are never undefined
                    if (!basePrice || !quotePrice) {
                        throw new Error(
                            `Missing prices for ${base} or ${quote}. This should not happen due to fail-fast validation.`,
                        );
                    }

                    const basePriceInQuote = basePrice / quotePrice;

                    // Determine target price based on token ordering
                    let targetPrice: number;
                    if (token0.symbol === base && token1.symbol === quote) {
                        targetPrice = basePriceInQuote;
                    } else if (
                        token0.symbol === quote &&
                        token1.symbol === base
                    ) {
                        targetPrice = 1 / basePriceInQuote;
                    } else {
                        throw new Error(
                            `Invalid token mapping: token0=${token0.symbol}, token1=${token1.symbol}, base=${base}, quote=${quote}`,
                        );
                    }

                    logger.info(
                        `Target price: ${targetPrice} (${token1.symbol}/${token0.symbol}) [${base}=$${basePrice}, ${quote}=$${quotePrice}]`,
                    );

                    // 1. Create pool if it doesn't exist
                    let poolAddress = await factory.getPool(
                        token0.address,
                        token1.address,
                        feeTier,
                    );

                    if (poolAddress === ethers.ZeroAddress) {
                        logger.info("Creating new pool...");

                        const sqrtPriceX96 = _calculateSqrtPriceX96(
                            targetPrice,
                            token0.decimals,
                            token1.decimals,
                        );

                        const createTx =
                            await manager.createAndInitializePoolIfNecessary(
                                token0.address,
                                token1.address,
                                feeTier,
                                sqrtPriceX96,
                            );
                        await createTx.wait();
                        results.transactionHashes?.push(createTx.hash);

                        poolAddress = await factory.getPool(
                            token0.address,
                            token1.address,
                            feeTier,
                        );
                        logger.info(`Pool created at: ${poolAddress}`);
                    } else {
                        logger.info(`Pool exists at: ${poolAddress}`);
                    }

                    // 2. Add bootstrap full-range liquidity first to prevent any swap failures
                    logger.info(
                        "Adding bootstrap full-range liquidity to ensure robustness...",
                    );
                    const bootstrapLiquiditySuccess =
                        await this._addBootstrapFullRangeLiquidity(
                            poolAddress,
                            config,
                        );
                    if (!bootstrapLiquiditySuccess) {
                        logger.warn(
                            "Bootstrap liquidity addition failed, but continuing...",
                        );
                    }

                    // 3. Check current pool state
                    const poolState = await _getPoolCurrentState(
                        poolAddress,
                        this.signer,
                    );
                    logger.info(
                        `Current state: tick=${
                            poolState.tick
                        }, liquidity=${poolState.liquidity.toString()}`,
                    );

                    // 4. Calculate target tick for price updates
                    // Use integer math via encodeSqrtRatioX96 to avoid float drift,
                    // deriving tick from precise sqrtRatioX96
                    const SCALE = 18;
                    const priceScaled = ethers.parseUnits(
                        targetPrice.toFixed(SCALE),
                        SCALE,
                    );
                    const amount1 =
                        priceScaled * 10n ** BigInt(token1.decimals);
                    const amount0 = 10n ** BigInt(token0.decimals + SCALE);
                    const sqrtRatioX96 = encodeSqrtRatioX96(
                        amount1.toString(),
                        amount0.toString(),
                    );
                    const targetTick = Math.max(
                        TickMath.MIN_TICK,
                        Math.min(
                            TickMath.MAX_TICK,
                            TickMath.getTickAtSqrtRatio(sqrtRatioX96),
                        ),
                    );

                    logger.info(
                        `Target tick: ${targetTick}, Current tick: ${poolState.tick}`,
                    );

                    // 5. Set price to target using precise swap
                    logger.info("Setting pool price to target...");
                    const priceSuccess = await this._preciseSwapToTarget(
                        poolAddress,
                        targetTick,
                        config,
                    );
                    if (!priceSuccess) {
                        logger.warn(
                            "Precise swap to target failed, but continuing...",
                        );
                    }

                    logger.info("Ensuring guard liquidity...");
                    const liquiditySuccess =
                        await this._addConcentratedLiquidity(
                            poolAddress,
                            config.liquidityUsd,
                            config,
                        );
                    if (!liquiditySuccess) {
                        throw new Error("Failed to add liquidity");
                    }

                    // 6. Market sanity quote validation (EXACT from reference): 1 base should cost ~price(base) in quote
                    await this._printMarketSanityQuoteOneBase(
                        poolAddress,
                        base,
                        quote,
                        feeTier,
                        config,
                    );

                    // For now, we've successfully processed this pool
                    results.poolsProcessed++;

                    logger.info(`Pool ${pairKey} processed successfully`);
                } catch (poolError) {
                    const errorMsg = `Failed to process pool ${pairKey}: ${poolError}`;
                    logger.error(`${errorMsg}`);
                    results.errors?.push(errorMsg);
                    results.success = false;
                }
            }

            if (results.success) {
                logger.info(
                    `All ${results.poolsProcessed} pools processed successfully!`,
                );
            } else {
                logger.error(
                    `Some pools failed. Processed: ${results.poolsProcessed}, Errors: ${results.errors?.length}`,
                );
            }
        } catch (error) {
            const errorMsg = `Critical error in executeUpdate: ${error}`;
            logger.error(`${errorMsg}`);
            results.errors?.push(errorMsg);
            results.success = false;
        }

        return results;
    }

    /**
     * Get service status
     */
    getStatus(): { walletAddress: string; hasConfig: boolean } {
        return {
            walletAddress: this.signer.address,
            hasConfig: this.config !== null,
        };
    }

    /**
     * Get current configuration
     */
    getConfig(): UniswapUpdateConfig | null {
        return this.config;
    }
}
