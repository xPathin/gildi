// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title Gildi Exchange Fund Manager Interface
/// @notice Interface for the Gildi Exchange Fund Manager contract.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
interface IGildiExchangeFundManager {
    // ========== Structs ==========

    /// @notice Represents an fund entry storing the buyer, operator, fundParticipant, and value in Marketplace Currency.
    struct Fund {
        /// @dev Entity receiving the tokens (beneficiary)
        address buyer;
        /// @dev Entity that executed the transaction
        address operator;
        /// @dev Entity with funds in fund (seller or fee recipient)
        address fundParticipant;
        /// @dev Whether this was executed through a proxy
        bool isProxyOperation;
        /// @dev Amount in Marketplace Currency
        FundAmount amount;
        /// @dev Payout currency
        address payoutCurrency;
    }

    /// @notice Represents an amount of tokens in a specific currency
    struct FundAmount {
        /// @dev The amount of tokens
        uint256 value;
        /// @dev The address of the currency token
        address currencyAddress;
    }

    // ========== View Functions ==========

    /// @notice Checks if a release has any funds
    /// @param _releaseId The ID of the release
    /// @return True if the release has funds, false otherwise
    function releaseHasFunds(uint256 _releaseId) external view returns (bool);

    // ========== Non-View Functions ==========

    /// @notice Adds funds to fund for a participant
    /// @param _releaseId The ID of the release
    /// @param _participant The address of the fund participant
    /// @param _buyer The address of the buyer
    /// @param _operator The address of the operator
    /// @param _isProxyOperation Whether this is a proxy operation
    /// @param _amount The amount to add to fund
    /// @param _amountCurrency The currency of the fund amount
    /// @param _payoutCurrency The currency to payout in
    function handleAddToFund(
        uint256 _releaseId,
        address _participant,
        address _buyer,
        address _operator,
        bool _isProxyOperation,
        uint256 _amount,
        address _amountCurrency,
        address _payoutCurrency
    ) external;

    /// @notice Cancels funds for a release in batches
    /// @param _releaseId The ID of the release
    /// @param _batchSize The number of funds to process in this batch
    /// @return processed The number of funds processed
    function handleCancelReleaseFunds(uint256 _releaseId, uint256 _batchSize) external returns (uint256 processed);

    /// @notice Claims funds for a participant of a release with custom slippage
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function claimFunds(uint256 _releaseId, address _fundParticipant, uint16 _slippageBps) external;

    /// @notice Claims funds for a participant of a release with default slippage (5%)
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    function claimFunds(uint256 _releaseId, address _fundParticipant) external;

    /// @notice Claims all funds for a participant across all releases with custom slippage
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function claimAllFunds(address _fundParticipant, uint16 _slippageBps) external;

    /// @notice Claims all funds for a participant across all releases with default slippage (5%)
    /// @param _fundParticipant The address of the fund participant
    function claimAllFunds(address _fundParticipant) external;
}
