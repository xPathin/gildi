// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title IGildiExchangeOrderBook
/// @notice Interface for the Gildi Exchange Order Book, which manages listings and provides order book functionality for the marketplace.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchangeOrderBook {
    /// @notice Represents a listing in the order book for a specific token release.
    struct Listing {
        /// @dev A unique identifier for the listing.
        uint256 id;
        /// @dev The ID of the token release being listed.
        uint256 releaseId;
        /// @dev The address of the seller who created the listing.
        address seller;
        /// @dev The price per item in USD.
        uint256 pricePerItem;
        /// @dev The currency in which the seller wants to receive payment (if different from the active release marketplace currency, a swap will be performed).
        address payoutCurrency;
        /// @dev The quantity of tokens being listed.
        uint256 quantity;
        /// @dev Slippage protection in basis points (100 = 1%, 500 = 5%), 0 means no slippage allowed.
        uint16 slippageBps;
        /// @dev The block timestamp when the listing was created (UNIX timestamp).
        uint256 createdAt;
        /// @dev The block timestamp when the listing was last modified (UNIX timestamp).
        uint256 modifiedAt;
        /// @dev The ID of the next listing in the linked list (ordered by price).
        uint256 nextListingId;
        /// @dev The ID of the previous listing in the linked list (ordered by price).
        uint256 prevListingId;
        /// @dev Optional address to receive funds from the sale.
        address fundsReceiver; // If address(0), defaults to seller
    }

    /// @notice Contains preview information for a potential purchase.
    struct PurchasePreview {
        /// @dev The total quantity available for purchase.
        uint256 totalQuantityAvailable;
        /// @dev The total price in marketplace currency.
        uint256 totalPriceInCurrency;
        /// @dev The address of the currency used for the purchase.
        address currency;
        /// @dev The total price in USD (using exchange's priceAskDecimals).
        uint256 totalPriceUsd;
    }

    // ========== View Functions ==========

    /// @notice Gets a listing by ID
    /// @param _listingId The listing ID
    /// @return The listing
    function getListing(uint256 _listingId) external view returns (Listing memory);

    /// @notice Gets all the listings of a specific seller
    /// @param _seller The address of the seller
    /// @return An array of listings for the seller
    function getListingsOfSeller(address _seller) external view returns (Listing[] memory);

    /// @notice Gets all the listings of a specific release, ordered by price
    /// @param _releaseId The ID of the release
    /// @param _cursor The cursor to start from
    /// @param _limit The limit of listings to return
    /// @return orderedListings An array of listings for the release
    /// @return cursor The cursor to continue from
    function getOrderedListings(
        uint256 _releaseId,
        uint256 _cursor,
        uint256 _limit
    ) external view returns (Listing[] memory orderedListings, uint256 cursor);

    /// @notice Gets the available buy quantity for a user
    /// @param _releaseId The release ID
    /// @param _user The user address
    /// @return The available quantity to buy
    function getAvailableBuyQuantity(uint256 _releaseId, address _user) external view returns (uint256);

    /// @notice Preview a purchase
    /// @param _releaseId The ID of the release to purchase
    /// @param _buyer The address of the buyer
    /// @param _amountToBuy The amount of tokens to buy
    /// @return Preview information for the purchase
    function previewPurchase(
        uint256 _releaseId,
        address _buyer,
        uint256 _amountToBuy
    ) external view returns (PurchasePreview memory);

    /// @notice Gets the first listing ID (with lowest price) for a specific release
    /// @param _releaseId The ID of the release
    /// @return The ID of the listing with the lowest price for this release
    function getHeadListingId(uint256 _releaseId) external view returns (uint256);

    /// @notice Gets the next listing ID in the price-ordered linked list
    /// @param _listingId The current listing ID
    /// @return The ID of the next listing with a higher price, or 0 if none exists
    function getNextListingId(uint256 _listingId) external view returns (uint256);

    /// @notice Gets the total quantity listed for a specific release
    /// @param _releaseId The ID of the release
    /// @return The total quantity listed
    function listedQuantities(uint256 _releaseId) external view returns (uint256);

    // ========== Non-View Functions ==========

    /// @notice Creates a listing
    /// @param _releaseId The ID of the release
    /// @param _seller The address of the seller
    /// @param _pricePerItem The price per item
    /// @param _quantity The quantity being listed
    /// @param _payoutCurrency The payout currency of the listing
    /// @param _slippageBps Optional slippage protection in basis points (100 = 1%, 500 = 5%)
    /// @dev Takes the slippage setting literally, 0 = no slippage, 10000 = 100%, does not make assumptions about the default, caller must know what they are doing
    function handleCreateListing(
        uint256 _releaseId,
        address _seller,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) external;

    /// @notice Modifies an existing listing's price, quantity, and slippage settings
    /// @param _listingId The ID of the listing to modify
    /// @param _pricePerItem The new price per item
    /// @param _quantity The new quantity (if 0, the listing will be removed)
    /// @param _payoutCurrency The new payout currency
    /// @param _slippageBps Slippage protection in basis points (100 = 1%, 500 = 5%)
    /// @dev Takes the slippage setting literally, 0 = no slippage, 10000 = 100%, does not make assumptions about the default, caller must know what they are doing
    function handleModifyListing(
        uint256 _listingId,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) external;

    /// @notice Removes a listing
    /// @param _listingId The ID of the listing to cancel
    function handleRemoveListing(uint256 _listingId) external;

    /// @notice Decreases a listing's quantity after a purchase
    /// @param _listingId The ID of the listing
    /// @param _quantityToBuy The amount to reduce from the listing's quantity (if this reduces quantity to 0, the listing will be removed)
    function handleDecreaseListingQuantity(uint256 _listingId, uint256 _quantityToBuy) external;

    /// @notice Unlists all listings of a release in batches.
    /// @param _releaseId The ID of the release
    /// @param _batchSize The batch size
    /// @return processedListings The number of listings processed
    function handleUnlistReleaseListings(
        uint256 _releaseId,
        uint256 _batchSize
    ) external returns (uint256 processedListings);
}
