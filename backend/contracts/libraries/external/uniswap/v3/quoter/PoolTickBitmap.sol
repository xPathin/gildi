// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {BitMath} from '@uniswap/v3-core/contracts/libraries/BitMath.sol';

/// @title PoolTickBitmap Library
/// @notice Stores a packed mapping of tick index to its initialized state
/// @author Gildi Company
library PoolTickBitmap {
    /// @dev Computes the position in the mapping where the initialized bit for a tick lives
    /// @param _tick The tick for which to compute the position
    /// @return wordPos The key in the mapping containing the word in which the bit is stored
    /// @return bitPos The bit position in the word where the flag is stored
    function position(int24 _tick) private pure returns (int16 wordPos, uint8 bitPos) {
        unchecked {
            wordPos = int16(_tick >> 8);
            bitPos = uint8(int8(_tick % 256));
        }
    }

    /// @dev Returns the next initialized tick contained in the same word (or adjacent word) as the tick that is either
    /// to the left (less than or equal to) or right (greater than) of the given tick
    /// @param _pool The pool for which to get the tick
    /// @param _tick The starting tick
    /// @param _tickSpacing The spacing between usable ticks
    /// @param _lte Whether to search for the next initialized tick to the left (less than or equal to the starting tick)
    /// @return next The next initialized or uninitialized tick up to 256 ticks away from the current tick
    /// @return initialized Whether the next tick is initialized, as the function only searches within up to 256 ticks
    function nextInitializedTickWithinOneWord(
        IUniswapV3Pool _pool,
        int24 _tickSpacing,
        int24 _tick,
        bool _lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = _tick / _tickSpacing;
        if (_tick < 0 && _tick % _tickSpacing != 0) compressed--; // round towards negative infinity

        if (_lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = _pool.tickBitmap(wordPos) & mask;

            initialized = masked != 0;
            next = initialized
                ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * _tickSpacing
                : (compressed - int24(uint24(bitPos))) * _tickSpacing;
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = _pool.tickBitmap(wordPos) & mask;

            initialized = masked != 0;
            next = initialized
                ? (compressed + 1 + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * _tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * _tickSpacing;
        }
    }
}
