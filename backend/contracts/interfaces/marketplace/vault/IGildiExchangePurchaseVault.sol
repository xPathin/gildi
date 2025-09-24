// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title IGildiExchangePurchaseVault
/// @notice Interface for USD Treasury Purchase Vault operations
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchangePurchaseVault {
    /// @notice Execution context used for intent execution with marketplace purchase parameters.
    /// @param releaseId represents the marketplace token identifier (e.g., releaseId).
    /// @param amount is the quantity intended to purchase.
    /// @param buyer is the wallet that will perform the purchase on the marketplace.
    struct ExecutionContext {
        uint256 releaseId;
        uint256 amount;
        address buyer;
    }

    /// @notice Gets remaining USD value for an intent
    /// @param _intentId The intent to query
    /// @return remaining The remaining USD value in cents
    function remainingUsd(bytes32 _intentId) external view returns (uint256 remaining);

    /// @notice Executes a purchase intent by sending tokens to beneficiary
    /// @param _intentId The intent to execute
    /// @param _tokenHint Preferred token address (optional)
    /// @param _ctx Execution context including releaseId, amount and buyer for optimal selection
    /// @return token The token that was sent
    /// @return tokenAmount The amount of tokens sent
    function executeIntent(
        bytes32 _intentId,
        address _tokenHint,
        ExecutionContext calldata _ctx
    ) external returns (address token, uint256 tokenAmount);

    /// @notice Settles a funded intent with actual USD spent and handles token refunds
    /// @param _intentId The intent to settle
    /// @param _actualUsdSpentCents Actual USD spent in vault cents (2 decimals)
    /// @param _refundToken Token address for refunds (address(0) if no refund)
    /// @param _refundTokenAmount Amount of tokens being refunded
    function settleIntent(
        bytes32 _intentId,
        uint256 _actualUsdSpentCents,
        address _refundToken,
        uint256 _refundTokenAmount
    ) external;

    /// @notice Checks if vault can fund a purchase with current token balances
    /// @param _intentValueUsdCents Intent value in USD cents
    /// @param _releaseId Release ID for purchase estimation
    /// @param _amount Amount of tokens to purchase
    /// @param _buyer Buyer address for estimation
    /// @return canFund True if purchase can be funded
    /// @return bestToken Address of the most cost-effective token (zero if can't fund)
    /// @return estimatedCost Estimated cost in best token (zero if can't fund)
    function canFundPurchase(
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) external view returns (bool canFund, address bestToken, uint256 estimatedCost);
}
