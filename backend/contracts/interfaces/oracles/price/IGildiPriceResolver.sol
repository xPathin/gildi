// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

/// @title Gildi Price Resolver Interface
/// @notice Interface that all price resolvers must implement
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer
interface IGildiPriceResolver {
    /// @notice Price data struct
    struct PriceData {
        /// @notice The price of the base asset in terms of the quote asset
        uint256 price;
        /// @notice The number of decimals for the price
        uint8 decimals;
        /// @notice The UNIX timestamp when the price was last updated
        uint256 timestamp;
    }

    /// @notice Retrieves the price data for a given pair ID
    /// @param pairId The identifier of the asset pair
    /// @return price The price data for the asset pair
    function getPrice(bytes32 pairId) external view returns (PriceData memory price);

    /// @notice Retrieves the price data for a given pair ID, with a maximum age
    /// @param pairId The identifier of the asset pair
    /// @param age The maximum age of the price data in seconds
    function getPriceNoOlderThan(bytes32 pairId, uint256 age) external view returns (PriceData memory priceData);
}
