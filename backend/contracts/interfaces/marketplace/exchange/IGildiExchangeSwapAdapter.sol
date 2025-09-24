// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title IGildiExchangeSwapAdapter
/// @notice Interface for a DEX/aggregator adapter that can
///         quote & swap from a user’s source token -> marketplace token
///         in an "exact out" fashion.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchangeSwapAdapter {
    /// @notice The route of the quote
    /// @param marketplaceAdapter The address of the marketplace adapter
    /// @param route The path of the quote
    /// @param fees The fees of the quote
    /// @param amounts The amounts of the quote
    /// @param virtualAmountsWithoutSlippage The virtual amounts of the quote without slippage
    struct QuoteRoute {
        address marketplaceAdapter;
        address[] route;
        uint128[] fees;
        uint128[] amounts;
        uint128[] virtualAmountsWithoutSlippage;
    }

    /// @notice The quote for a swap in
    /// @param sourceTokenRequired The amount of source token required
    /// @param rawQuoteData The raw quote data
    /// @param quoteRoute The quote route
    /// @param validRoute Whether the route is valid
    struct SwapInQuote {
        uint256 sourceTokenRequired;
        bytes rawQuoteData;
        QuoteRoute quoteRoute;
        bool validRoute;
    }

    /// @notice The quote for a swap out
    /// @param targetTokenOut The target token
    /// @param rawQuoteData The raw quote data
    /// @param quoteRoute The quote route
    /// @param validRoute Whether the route is valid
    struct SwapOutQuote {
        uint256 targetTokenOut;
        bytes rawQuoteData;
        QuoteRoute quoteRoute;
        bool validRoute;
    }

    /// @notice Quotes the amount of `_sourceToken` required to get `_marketplaceAmountDesired` of `_marketplaceToken`.
    /// @param _sourceToken The token to swap from.
    /// @param _marketplaceToken The token to swap to.
    /// @param _marketplaceAmountDesired The amount of `_marketplaceToken` desired.
    /// @return quote The swap in quote containing required source token amount, quote data and route information
    function quoteSwapIn(
        address _sourceToken,
        address _marketplaceToken,
        uint256 _marketplaceAmountDesired
    ) external view returns (SwapInQuote memory quote);

    /// @notice Performs an "exact out" swap to get `_marketplaceAmount` of `_marketplaceToken`.
    /// @param _sourceToken The token to swap from.
    /// @param _marketplaceToken The token to swap to.
    /// @param _sourceAmountMax The max `_sourceToken` we can spend (slippage buffer).
    /// @param _marketplaceAmount The exact marketplace tokens we want out.
    /// @param _to The recipient of the marketplace tokens.
    /// @param _quoteData The data previously returned by `quoteSwapIn`.
    function swapIn(
        address _sourceToken,
        address _marketplaceToken,
        uint256 _sourceAmountMax,
        uint256 _marketplaceAmount,
        address _to,
        bytes calldata _quoteData
    ) external returns (uint256 sourceSpent);

    /// @notice Quotes the amount of `_targetToken` you can get by providing `_sourceAmount` of `_sourceToken`.
    /// @param _sourceToken The token to swap from.
    /// @param _targetToken The token to swap to.
    /// @param _sourceAmount The amount of `_sourceToken` available.
    /// @return quote The quote.
    function quoteSwapOut(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount
    ) external view returns (SwapOutQuote memory quote);

    /// @notice Performs an "exact in" swap to convert `_sourceAmount` of `_sourceToken` into `_targetToken`.
    /// @param _sourceToken The token to swap from.
    /// @param _targetToken The token to swap to.
    /// @param _sourceAmount The exact amount of `_sourceToken` to swap.
    /// @param _minTargetAmount The minimum amount of `_targetToken` to receive (slippage protection).
    /// @param _to The recipient of the target tokens.
    /// @param _quoteData The data previously returned by `quoteSwapOut`.
    function swapOut(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount,
        uint256 _minTargetAmount,
        address _to,
        bytes calldata _quoteData
    ) external returns (uint256 targetReceived);
}
