// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import './IGildiPriceResolver.sol';

/// @title Gildi Price Oracle Interface
/// @notice Interface for the consumer-facing Gildi Price Oracle
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiPriceOracle is IGildiPriceResolver {
    /// @notice Represents an asset in the system
    struct Asset {
        /// @dev Unique identifier for the asset
        uint256 id;
        /// @dev The asset's symbol (e.g., BTC, ETH)
        string symbol;
        /// @dev The asset's full name
        string name;
    }

    /// @notice Information about a trading pair
    struct PairInfo {
        /// @dev Unique identifier for the pair
        bytes32 pairId;
        /// @dev The base asset in the pair
        Asset baseAsset;
        /// @dev The quote asset in the pair
        Asset quoteAsset;
    }

    /// @dev Thrown when an invalid pair ID is provided
    error InvalidPairId();

    /// @notice Adds a pair using asset IDs
    /// @param _baseAssetId The ID of the base asset
    /// @param _quoteAssetId The ID of the quote asset
    /// @param _resolver The resolver contract for the asset pair
    function addPair(uint256 _baseAssetId, uint256 _quoteAssetId, IGildiPriceResolver _resolver) external;

    /// @notice Retrieves the resolver for a specific asset pair
    /// @param _pairId The identifier of the asset pair
    function getResolver(bytes32 _pairId) external view returns (IGildiPriceResolver resolver);

    /// @notice Fetches a list of all registered pairs in "BASE/QUOTE" string form
    /// @return An array of registered pairs
    function getPairs() external view returns (PairInfo[] memory);

    /// @notice Adds a new asset
    /// @param _symbol The symbol of the asset
    /// @param _name The name of the asset
    /// @return The ID of the newly added asset
    function addAsset(string memory _symbol, string memory _name) external returns (uint256);

    /// @notice Returns all registered assets
    /// @return An array of registered assets
    function getAssets() external view returns (Asset[] memory);

    /// @notice Returns an asset by ID
    /// @param _assetId The ID of the asset
    /// @return The asset details
    function getAssetById(uint256 _assetId) external view returns (Asset memory);

    /// @notice Returns pairs that use the specified asset ID as quote
    /// @param _quoteAssetId The ID of the quote asset
    /// @return An array of registered pairs
    function getPairsByQuoteAsset(uint256 _quoteAssetId) external view returns (string[] memory);

    /// @notice Retrieves price data by numeric IDs
    /// @param _baseAssetId The ID of the base asset
    /// @param _quoteAssetId The ID of the quote asset
    /// @return The price data for the asset pair
    function getPriceById(uint256 _baseAssetId, uint256 _quoteAssetId) external view returns (PriceData memory);

    /// @notice Checks if a pair with the given ID exists
    /// @param _pairId The identifier of the asset pair
    /// @return True if the pair exists
    function pairExistsById(bytes32 _pairId) external view returns (bool);
}
