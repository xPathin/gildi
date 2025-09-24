// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IGildiExchange} from './IGildiExchange.sol';

/// @title IGildiExchangePaymentProcessor
/// @notice Interface for the Gildi Exchange Payment Processor.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchangePaymentProcessor {
    /// @notice Gets the price feed ID for a currency
    /// @param _currency The currency address
    /// @return The price feed ID
    function getPriceFeedId(address _currency) external view returns (bytes32);

    /// @notice Converts a price in USD to the equivalent amount in the specified currency
    /// @param _priceInUSD The price in USD to convert
    /// @param _currency The address of the currency to convert to
    /// @return The equivalent amount in the specified currency
    function quoteInCurrency(uint256 _priceInUSD, address _currency) external view returns (uint256);

    /// @notice Processes payment with fees.
    ///      Calculates fees, transfers funds to fee recipients, and optionally creates funds
    /// @param _releaseId The ID of the release
    /// @param _buyer The address of the buyer
    /// @param _seller The address of the seller
    /// @param _value The value to process fees for
    /// @param _amountCurrency The currency of the amount
    /// @param _createFund Whether to create an fund
    /// @param _operator The address of the operator
    /// @param _listingId The ID of the listing
    /// @param _isProxyOperation Whether this is a proxy operation
    /// @param _listingPayoutCurrency The currency to payout in from the listing
    function handleProcessPaymentWithFees(
        uint256 _releaseId,
        address _buyer,
        address _seller,
        uint256 _value,
        address _amountCurrency,
        bool _createFund,
        address _operator,
        bool _isProxyOperation,
        uint256 _listingId,
        address _listingPayoutCurrency,
        uint16 _slippageBps
    ) external;
}
