// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity ^0.8.0;

/// @title QuoterV2 Interface
/// @notice Supports quoting the calculated amounts from exact input or exact output swaps.
/// @notice For each pool also tells you the number of initialized ticks crossed and the sqrt price of the pool after the swap.
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IUniswapV3ViewQuoter {
    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param _path The path of the swap, i.e. each token pair and the pool fee
    /// @param _amountIn The amount of the first token to swap
    /// @return amountOut The amount of the last token that would be received
    /// @return sqrtPriceX96AfterList List of the sqrt price after the swap for each pool in the path
    /// @return initializedTicksCrossedList List of number of initialized ticks loaded
    function quoteExactInput(
        bytes memory _path,
        uint256 _amountIn
    )
        external
        view
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList
        );

    /// @notice Parameters for quoting a single exact input swap with explicit pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param amountIn The desired input amount
    /// @param pool The address of the pool to consider for the pair
    /// @param fee The fee of the pool to consider for the pair
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    struct QuoteExactInputSingleWithPoolParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        address pool;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param _params The params for the quote, which contains:
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amountIn The desired input amount
    /// fee The fee of the pool to consider for the pair
    /// pool The address of the pool to consider for the pair
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of tokenOut that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks loaded
    function quoteExactInputSingleWithPool(
        QuoteExactInputSingleWithPoolParams memory _params
    ) external view returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed);

    /// @notice Parameters for quoting a single exact input swap
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param amountIn The desired input amount
    /// @param fee The fee of the token pool to consider for the pair
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param _params The params for the quote, which contains:
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amountIn The desired input amount
    /// fee The fee of the token pool to consider for the pair
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of tokenOut that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks loaded
    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory _params
    ) external view returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed);

    /// @notice Parameters for quoting a single exact output swap with explicit pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param amount The desired output amount
    /// @param fee The fee of the token pool to consider for the pair
    /// @param pool The address of the pool to consider for the pair
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    struct QuoteExactOutputSingleWithPoolParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        address pool;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Returns the amount in required to receive the given exact output amount but for a swap of a single pool
    /// @param _params The params for the quote, which contains:
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amount The desired output amount
    /// fee The fee of the token pool to consider for the pair
    /// pool The address of the pool to consider for the pair
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountIn The amount required as the input for the swap in order to receive amountOut
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks loaded
    function quoteExactOutputSingleWithPool(
        QuoteExactOutputSingleWithPoolParams memory _params
    ) external view returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed);

    /// @notice Parameters for quoting a single exact output swap
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param amount The desired output amount
    /// @param fee The fee of the token pool to consider for the pair
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Returns the amount in required to receive the given exact output amount but for a swap of a single pool
    /// @param _params The params for the quote, which contains:
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// amount The desired output amount
    /// fee The fee of the token pool to consider for the pair
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountIn The amount required as the input for the swap in order to receive amountOut
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks loaded
    function quoteExactOutputSingle(
        QuoteExactOutputSingleParams memory _params
    ) external view returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed);

    /// @notice Returns the amount in required for a given exact output swap without executing the swap
    /// @param _path The path of the swap, i.e. each token pair and the pool fee. Path must be provided in reverse order
    /// @param _amountOut The amount of the last token to receive
    /// @return amountIn The amount of first token required to be paid
    /// @return sqrtPriceX96AfterList List of the sqrt price after the swap for each pool in the path
    /// @return initializedTicksCrossedList List of the initialized ticks that the swap crossed for each pool in the path
    function quoteExactOutput(
        bytes memory _path,
        uint256 _amountOut
    )
        external
        view
        returns (uint256 amountIn, uint160[] memory sqrtPriceX96AfterList, uint32[] memory initializedTicksCrossedList);
}
