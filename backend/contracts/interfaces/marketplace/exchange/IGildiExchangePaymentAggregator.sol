// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import './IGildiExchangeSwapAdapter.sol';
import './IGildiExchange.sol';

/// @title IGildiExchangePaymentAggregator
/// @notice Interface for marketplace payment operations including swap functionality
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchangePaymentAggregator {
    /// @notice Executes a swap out operation to convert source tokens to a target token.
    /// @param _amount The amount of source tokens to swap.
    /// @param _sourceCurrency The address of the source token.
    /// @param _targetToken The token to swap to.
    /// @param _minTargetAmount The minimum amount of target tokens to receive (slippage protection).
    /// @param _recipient The recipient of the target tokens.
    /// @return targetReceived The amount of target tokens received.
    function swapOut(
        uint256 _amount,
        address _sourceCurrency,
        address _targetToken,
        uint256 _minTargetAmount,
        address _recipient
    ) external returns (uint256 targetReceived);

    /// @notice Previews a swap out operation to check if there's a valid route and estimate the output amount.
    /// @param _amount The amount of source tokens to swap.
    /// @param _sourceCurrency The address of the source token.
    /// @param _targetToken The token to swap to.
    /// @return hasValidRoute Whether there's a valid route for the swap.
    /// @return expectedTargetAmount The expected amount of target tokens to receive.
    /// @return bestRoute The best route for the swap.
    function previewSwapOut(
        uint256 _amount,
        address _sourceCurrency,
        address _targetToken
    )
        external
        view
        returns (
            bool hasValidRoute,
            uint256 expectedTargetAmount,
            IGildiExchangeSwapAdapter.QuoteRoute memory bestRoute
        );

    /// @notice Executes the purchase payment flow.
    /// @param _releaseId The release ID.
    /// @param _amount The amount to purchase.
    /// @param _sourceToken The token used for payment (address(0) means native).
    /// @param _sourceMaxAmount Maximum amount of _sourceToken to spend.
    /// @return amountUsdSpent The amount spent in USD
    function purchase(
        uint256 _releaseId,
        uint256 _amount,
        address _sourceToken,
        uint256 _sourceMaxAmount
    ) external payable returns (uint256 amountUsdSpent);

    /// @notice Estimates the amount of `_sourceToken` required to get `_amount` of `_releaseId` for `_buyer` of the marketplace token and returns the current best route.
    /// @param _releaseId The release ID.
    /// @param _amount The amount of the release.
    /// @param _buyer The buyer of the release.
    /// @param _sourceToken The token to swap from.
    /// @return sourceNeeded The amount of `_sourceToken` required.
    /// @return releaseCurrency The active martketplace currency of the release.
    /// @return quoteRoute The route of the quote.
    /// @return totalPriceUsd The total price in USD (using exchange's priceAskDecimals).
    function estimatePurchase(
        uint256 _releaseId,
        uint256 _amount,
        address _buyer,
        address _sourceToken
    )
        external
        view
        returns (
            uint256 sourceNeeded,
            address releaseCurrency,
            IGildiExchangeSwapAdapter.QuoteRoute memory quoteRoute,
            uint256 totalPriceUsd
        );

    /// @notice Returns the GildiExchange contract instance.
    /// @return The GildiExchange contract.
    function getGildiExchange() external view returns (IGildiExchange);
}
