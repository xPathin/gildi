// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity ^0.8.0;

import {SwapMath} from '../core/SwapMath.sol';
import {TickMath} from '../core/TickMath.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {LowGasSafeMath} from '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';
import {SafeCast} from '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
import {LiquidityMath} from '@uniswap/v3-core/contracts/libraries/LiquidityMath.sol';
import {PoolTickBitmap} from './PoolTickBitmap.sol';

/// @title QuoterMath Library
/// @notice A library for performing quote calculations for Uniswap V3 pools
/// @author Gildi Company
library QuoterMath {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @notice Contains price and tick information for a pool
    /// @param sqrtPriceX96 The current price as a sqrt price ratio
    /// @param tick The current tick
    /// @param tickSpacing The tick spacing configuration for the pool
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        int24 tickSpacing;
    }

    /// @notice Parameters for quote calculation, packed to avoid stack limit issues
    /// @param zeroForOne Whether the swap is from token0 to token1
    /// @param exactInput Whether the swap is exact input or exact output
    /// @param fee The fee tier of the pool
    /// @param sqrtPriceLimitX96 The price limit of the swap in sqrt price
    struct QuoteParams {
        bool zeroForOne;
        bool exactInput;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @dev Fills Slot0 struct with current pool state
    /// @param _pool The Uniswap V3 pool to query
    /// @return slot0 The filled Slot0 struct with current price and tick data
    function fillSlot0(IUniswapV3Pool _pool) private view returns (Slot0 memory slot0) {
        (slot0.sqrtPriceX96, slot0.tick, , , , , ) = _pool.slot0();
        slot0.tickSpacing = _pool.tickSpacing();

        return slot0;
    }

    /// @notice Caches data used during the swap calculation to avoid stack depth issues
    /// @param feeProtocol The protocol fee for the input token
    /// @param liquidityStart Liquidity at the beginning of the swap
    /// @param blockTimestamp The timestamp of the current block
    /// @param tickCumulative The current value of the tick accumulator, computed only if we cross an initialized tick
    /// @param secondsPerLiquidityCumulativeX128 The current value of seconds per liquidity accumulator
    /// @param computedLatestObservation Whether we've computed and cached the above two accumulators
    struct SwapCache {
        uint8 feeProtocol;
        uint128 liquidityStart;
        uint32 blockTimestamp;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
        bool computedLatestObservation;
    }

    /// @notice The top level state of the swap, tracks the calculation progress
    /// @param amountSpecifiedRemaining The amount remaining to be swapped in/out of the input/output asset
    /// @param amountCalculated The amount already swapped out/in of the output/input asset
    /// @param sqrtPriceX96 Current sqrt(price) of the pool
    /// @param tick The tick associated with the current price
    /// @param feeGrowthGlobalX128 The global fee growth of the input token
    /// @param protocolFee Amount of input token paid as protocol fee
    /// @param liquidity The current liquidity in range
    struct SwapState {
        int256 amountSpecifiedRemaining;
        int256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
        uint256 feeGrowthGlobalX128;
        uint128 protocolFee;
        uint128 liquidity;
    }

    /// @notice Intermediate calculations for a single step of a swap
    /// @param sqrtPriceStartX96 The price at the beginning of the step
    /// @param tickNext The next tick to swap to from the current tick in the swap direction
    /// @param initialized Whether tickNext is initialized or not
    /// @param sqrtPriceNextX96 sqrt(price) for the next tick (1/0)
    /// @param amountIn How much is being swapped in in this step
    /// @param amountOut How much is being swapped out
    /// @param feeAmount How much fee is being paid in
    struct StepComputations {
        uint160 sqrtPriceStartX96;
        int24 tickNext;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
    }

    /// @notice Utility function called by the quote functions to calculate the amounts in/out for a v3 swap
    /// @dev Returns (0,0,0,0) early if the input amount is zero or the pool does not exist (code size is zero)
    /// @param _pool The Uniswap v3 pool interface to query for the swap
    /// @param _amount The amount to swap (positive for exactInput, negative for exactOutput)
    /// @param _quoteParams A packed struct of parameters used during quote calculation
    /// @return amount0 The amount of token0 sent in or out of the pool
    /// @return amount1 The amount of token1 sent in or out of the pool
    /// @return sqrtPriceAfterX96 The square root price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks crossed during the swap
    function quote(
        IUniswapV3Pool _pool,
        int256 _amount,
        QuoteParams memory _quoteParams
    )
        internal
        view
        returns (int256 amount0, int256 amount1, uint160 sqrtPriceAfterX96, uint32 initializedTicksCrossed)
    {
        if (_amount == 0 || address(_pool).code.length == 0) {
            return (0, 0, 0, 0);
        }

        _quoteParams.exactInput = _amount > 0;
        initializedTicksCrossed = 1;

        Slot0 memory slot0 = fillSlot0(_pool);

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: _amount,
            amountCalculated: 0,
            sqrtPriceX96: slot0.sqrtPriceX96,
            tick: slot0.tick,
            feeGrowthGlobalX128: 0,
            protocolFee: 0,
            liquidity: _pool.liquidity()
        });

        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != _quoteParams.sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = PoolTickBitmap.nextInitializedTickWithinOneWord(
                _pool,
                slot0.tickSpacing,
                state.tick,
                _quoteParams.zeroForOne
            );

            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (
                    _quoteParams.zeroForOne
                        ? step.sqrtPriceNextX96 < _quoteParams.sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > _quoteParams.sqrtPriceLimitX96
                )
                    ? _quoteParams.sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                _quoteParams.fee
            );

            if (_quoteParams.exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    (, int128 liquidityNet, , , , , , ) = _pool.ticks(step.tickNext);

                    if (_quoteParams.zeroForOne) liquidityNet = -liquidityNet;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);

                    initializedTicksCrossed++;
                }

                state.tick = _quoteParams.zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        (amount0, amount1) = _quoteParams.zeroForOne == _quoteParams.exactInput
            ? (_amount - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, _amount - state.amountSpecifiedRemaining);

        sqrtPriceAfterX96 = state.sqrtPriceX96;
    }
}
