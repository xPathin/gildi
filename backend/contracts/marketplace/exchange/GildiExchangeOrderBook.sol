// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IGildiExchange} from '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import {IGildiExchangeOrderBook} from '../../interfaces/marketplace/exchange/IGildiExchangeOrderBook.sol';
import {IGildiManager} from '../../interfaces/manager/IGildiManager.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {SharedErrors} from '../../libraries/marketplace/exchange/SharedErrors.sol';

/// @title Gildi Exchange Order Book
/// @notice Manages listings and order book functionality for the Gildi Exchange marketplace.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiExchangeOrderBook is Initializable, Context, IGildiExchangeOrderBook {
    // ========== Events ==========
    /// @notice Emitted when a new listing is created
    /// @param listingId The ID of the listing
    /// @param releaseId The ID of the release
    /// @param seller The address of the seller
    /// @param price The price per item
    /// @param quantity The quantity listed
    event Listed(
        uint256 indexed listingId,
        uint256 indexed releaseId,
        address indexed seller,
        uint256 price,
        uint256 quantity
    );

    /// @notice Emitted when a listing is removed
    /// @param listingId The ID of the listing
    /// @param releaseId The ID of the release
    /// @param seller The address of the seller
    /// @param quantity The quantity unlisted
    event Unlisted(uint256 indexed listingId, uint256 indexed releaseId, address indexed seller, uint256 quantity);

    /// @notice Emitted when a listing is modified
    /// @param listingId The ID of the listing
    /// @param releaseId The ID of the release
    /// @param seller The address of the seller
    /// @param price The new price per item
    /// @param quantity The new quantity
    event Modified(
        uint256 indexed listingId,
        uint256 indexed releaseId,
        address indexed seller,
        uint256 price,
        uint256 quantity
    );

    // ========== Errors ==========
    /// @dev Error thrown when the caller is not the GildiExchange
    error NotGildiExchange();

    // ========== Storage Variables ==========
    /// @notice The GildiExchange contract that this order book is associated with
    IGildiExchange public gildiExchange;
    /// @notice The GildiManager contract used for token management
    IGildiManager public gildiManager;

    /// @dev The next available listing ID to assign
    uint256 private nextListingId;
    /// @dev Mapping from listing ID to Listing struct
    mapping(uint256 => Listing) private listings;
    /// @dev Mapping from release ID to an array of listing IDs for that release
    mapping(uint256 => uint256[]) private tokenListings;
    /// @dev Mapping from seller address to an array of their listing IDs
    mapping(address => uint256[]) private sellerListings;
    /// @dev Mapping from release ID to the ID of the listing with the lowest price for that release
    mapping(uint256 => uint256) private headListingIds;
    /// @dev Mapping from release ID to the ID of the listing with the highest price for that release
    mapping(uint256 => uint256) private tailListingIds;
    /// @dev Mapping from release ID to the total quantity of tokens listed for that release
    mapping(uint256 => uint256) private listedQuantitiesMap;

    /// @notice Ensures that only the GildiExchange contract can call this function
    modifier onlyGildiExchange() {
        if (msg.sender != address(gildiExchange)) {
            revert NotGildiExchange();
        }
        _;
    }

    // ========== Constructor and Initializer ==========

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _gildiExchange The address of the GildiExchange contract
    /// @param _gildiManager The address of the GildiManager contract
    function initialize(address _gildiExchange, address _gildiManager) external initializer {
        gildiExchange = IGildiExchange(_gildiExchange);
        gildiManager = IGildiManager(_gildiManager);
        nextListingId = 1;
    }

    // ========== External View Functions ==========

    /// @inheritdoc IGildiExchangeOrderBook
    function getListing(uint256 _listingId) external view override returns (Listing memory) {
        return listings[_listingId];
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function getListingsOfSeller(address _seller) external view override returns (Listing[] memory) {
        uint256[] storage listingIds = sellerListings[_seller];
        Listing[] memory result = new Listing[](listingIds.length);

        for (uint256 i = 0; i < listingIds.length; i++) {
            result[i] = listings[listingIds[i]];
        }

        return result;
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function getOrderedListings(
        uint256 _releaseId,
        uint256 _cursor,
        uint256 _limit
    ) external view override returns (Listing[] memory orderedListings, uint256 cursor) {
        // 1. Sort the listings
        uint256[] memory sortedListingIds = new uint256[](tokenListings[_releaseId].length);
        uint256 count = 0;
        uint256 currentId = headListingIds[_releaseId];

        while (currentId != 0) {
            sortedListingIds[count] = currentId;
            count++;
            currentId = listings[currentId].nextListingId;
        }

        // 2. Determine the number of listings to return
        uint256 remaining = (count > _cursor) ? count - _cursor : 0;
        uint256 resultSize = remaining < _limit ? remaining : _limit;

        // 3. Get the listings
        Listing[] memory result = new Listing[](resultSize);
        uint256 resultIndex = 0;

        for (uint256 i = _cursor; i < count && resultIndex < resultSize; i++) {
            result[resultIndex] = listings[sortedListingIds[i]];
            resultIndex++;
        }

        // If all listings are retrieved, set nextCursor to the sortedIndex
        uint256 nextCursor = _cursor + resultSize;
        if (nextCursor >= count) {
            nextCursor = count;
        }

        return (result, nextCursor);
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function getAvailableBuyQuantity(uint256 _releaseId, address _user) external view override returns (uint256) {
        // Subtract user's listed tokens from the total available to avoid self-purchases
        uint256 qty = listedQuantitiesMap[_releaseId];

        for (uint256 i = 0; i < sellerListings[_user].length; i++) {
            if (listings[sellerListings[_user][i]].releaseId == _releaseId) {
                qty -= listings[sellerListings[_user][i]].quantity;
            }
        }

        return qty;
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function previewPurchase(
        uint256 _releaseId,
        address _buyer,
        uint256 _amountToBuy
    ) external view override returns (PurchasePreview memory) {
        IGildiExchange.AppEnvironment memory $ = gildiExchange.getAppEnvironment();

        uint256 remainingToBuy = _amountToBuy;
        uint256 totalPriceInMarketplaceCurrency = 0;
        uint256 totalPriceUsd = 0;
        uint256 totalAvailable = 0;

        uint256 current = headListingIds[_releaseId];

        address releaseAsset = gildiExchange.getActiveMarketplaceReleaseAsset(_releaseId);
        while (current != 0 && remainingToBuy > 0) {
            Listing storage listing = listings[current];

            // Skip listing if the seller *is* the buyer
            if (listing.seller == _buyer) {
                current = listing.nextListingId;
                continue;
            }

            // Take as many tokens from this listing as we can
            uint256 localQty = listing.quantity;
            if (localQty == 0) {
                // listing is empty; move on
                current = listing.nextListingId;
                continue;
            }

            // chunk = min(remainingToBuy, localQty)
            uint256 chunk = (localQty >= remainingToBuy) ? remainingToBuy : localQty;

            uint256 mcPricePerItem = $.settings.paymentProcessor.quoteInCurrency(listing.pricePerItem, releaseAsset);

            // add this chunk's cost to totals
            totalPriceInMarketplaceCurrency += (mcPricePerItem * chunk);
            totalPriceUsd += (listing.pricePerItem * chunk); // pricePerItem is in USD with priceAskDecimals
            totalAvailable += chunk;

            // reduce remaining
            remainingToBuy -= chunk;

            // Move on to next listing
            current = listing.nextListingId;
        }

        return
            PurchasePreview({
                totalQuantityAvailable: totalAvailable,
                totalPriceInCurrency: totalPriceInMarketplaceCurrency,
                currency: releaseAsset,
                totalPriceUsd: totalPriceUsd
            });
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function getHeadListingId(uint256 _releaseId) external view override returns (uint256) {
        return headListingIds[_releaseId];
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function getNextListingId(uint256 _listingId) external view override returns (uint256) {
        return listings[_listingId].nextListingId;
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function listedQuantities(uint256 _releaseId) external view override returns (uint256) {
        return listedQuantitiesMap[_releaseId];
    }

    // ========== External Non-View Functions ==========

    /// @inheritdoc IGildiExchangeOrderBook
    function handleCreateListing(
        uint256 _releaseId,
        address _seller,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) external override onlyGildiExchange {
        if (_quantity == 0) {
            revert SharedErrors.ParamError();
        }

        gildiManager.lockTokens(_seller, _releaseId, _quantity);

        uint256 listingId = nextListingId;
        nextListingId++;

        Listing memory newListing = Listing({
            id: listingId,
            releaseId: _releaseId,
            seller: _seller,
            pricePerItem: _pricePerItem,
            payoutCurrency: _payoutCurrency,
            quantity: _quantity,
            createdAt: block.timestamp,
            modifiedAt: block.timestamp,
            nextListingId: 0,
            prevListingId: 0,
            slippageBps: _slippageBps,
            fundsReceiver: _fundsReceiver
        });

        listings[listingId] = newListing;

        // Insert the listing into the correct position based on price
        _insertListingInOrder(_releaseId, listingId, _pricePerItem);

        listedQuantitiesMap[_releaseId] += newListing.quantity;
        sellerListings[_seller].push(listingId);
        tokenListings[_releaseId].push(listingId);

        emit Listed(listingId, _releaseId, _seller, _pricePerItem, _quantity);
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function handleModifyListing(
        uint256 _listingId,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) external override onlyGildiExchange {
        Listing storage listing = listings[_listingId];

        if (listing.id != _listingId) {
            revert SharedErrors.ListingError(_listingId);
        }

        if (_quantity == 0) {
            handleRemoveListing(_listingId);
            return;
        }

        uint256 oldQuantity = listing.quantity;
        uint256 newQuantity = _quantity;

        if (newQuantity < oldQuantity) {
            uint256 difference = oldQuantity - newQuantity;
            gildiManager.unlockTokens(listing.seller, listing.releaseId, difference);
            listedQuantitiesMap[listing.releaseId] -= difference;
        } else if (newQuantity > oldQuantity) {
            uint256 difference = newQuantity - oldQuantity;

            gildiManager.lockTokens(listing.seller, listing.releaseId, difference);
            listedQuantitiesMap[listing.releaseId] += difference;
        }

        // Remove the listing from the linked list
        _clearListingFromLinkedList(_listingId);

        // Update the listing with new price and quantity
        listing.pricePerItem = _pricePerItem;
        listing.quantity = newQuantity;
        listing.modifiedAt = block.timestamp;
        listing.slippageBps = _slippageBps;
        listing.payoutCurrency = _payoutCurrency;
        listing.fundsReceiver = _fundsReceiver;

        // Re-insert into the correct position based on new price
        _insertListingInOrder(listing.releaseId, listing.id, listing.pricePerItem);

        emit Modified(_listingId, listing.releaseId, listing.seller, _pricePerItem, _quantity);
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function handleRemoveListing(uint256 _listingId) public override onlyGildiExchange {
        Listing memory listing = listings[_listingId];
        if (listing.id != _listingId) {
            revert SharedErrors.ListingError(_listingId);
        }

        if (listing.quantity > 0) {
            gildiManager.unlockTokens(listing.seller, listing.releaseId, listing.quantity);
        }

        _clearListingFromLinkedList(_listingId);

        uint256[] storage sellerArray = sellerListings[listing.seller];
        for (uint256 i = 0; i < sellerArray.length; i++) {
            if (sellerArray[i] == _listingId) {
                sellerArray[i] = sellerArray[sellerArray.length - 1];
                sellerArray.pop();
                break;
            }
        }

        listedQuantitiesMap[listing.releaseId] -= listing.quantity;

        uint256[] storage listingArray = tokenListings[listing.releaseId];
        for (uint256 i = 0; i < listingArray.length; i++) {
            if (listingArray[i] == _listingId) {
                listingArray[i] = listingArray[listingArray.length - 1];
                listingArray.pop();
                break;
            }
        }

        emit Unlisted(listing.id, listing.releaseId, listing.seller, listing.quantity);

        delete listings[_listingId];
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function handleDecreaseListingQuantity(
        uint256 _listingId,
        uint256 _quantityToBuy
    ) external override onlyGildiExchange {
        Listing storage listing = listings[_listingId];

        if (listing.id != _listingId) {
            revert SharedErrors.ListingError(_listingId);
        }

        if (_quantityToBuy > listing.quantity) {
            revert SharedErrors.ParamError();
        }

        listing.quantity -= _quantityToBuy;
        listedQuantitiesMap[listing.releaseId] -= _quantityToBuy;
        listing.modifiedAt = block.timestamp;

        if (listing.quantity == 0) {
            handleRemoveListing(_listingId);
        }
    }

    /// @inheritdoc IGildiExchangeOrderBook
    function handleUnlistReleaseListings(
        uint256 _releaseId,
        uint256 _batchSize
    ) external override onlyGildiExchange returns (uint256 processedListings) {
        uint256[] storage listingIds = tokenListings[_releaseId];
        while (processedListings < _batchSize && listingIds.length > 0) {
            // Process from the end of listings to avoid shifting elements
            uint256 listingId = listingIds[listingIds.length - 1];
            handleRemoveListing(listingId); // This will also emit the event and handle book-keeping
            processedListings++;
        }

        return (processedListings);
    }

    // ========== Internal Functions ==========

    /// @dev Clear a listing from the linked list
    /// @param _listingId The ID of the listing to clear
    function _clearListingFromLinkedList(uint256 _listingId) internal {
        Listing storage listing = listings[_listingId];

        // If the listing is the head
        if (headListingIds[listing.releaseId] == _listingId) {
            headListingIds[listing.releaseId] = listing.nextListingId;
        }

        // If the listing is the tail
        if (tailListingIds[listing.releaseId] == _listingId) {
            tailListingIds[listing.releaseId] = listing.prevListingId;
        }

        // Update neighbors
        if (listing.prevListingId != 0) {
            listings[listing.prevListingId].nextListingId = listing.nextListingId;
        }

        if (listing.nextListingId != 0) {
            listings[listing.nextListingId].prevListingId = listing.prevListingId;
        }

        listing.nextListingId = 0;
        listing.prevListingId = 0;
    }

    /// @dev Insert a listing into the correct position in the linked list based on price
    /// @param _releaseId The ID of the release
    /// @param _listingId The ID of the listing
    /// @param _pricePerItem The price per item
    function _insertListingInOrder(uint256 _releaseId, uint256 _listingId, uint256 _pricePerItem) internal {
        if (headListingIds[_releaseId] == 0) {
            headListingIds[_releaseId] = _listingId;
            tailListingIds[_releaseId] = _listingId;
            return;
        }

        if (_pricePerItem < listings[headListingIds[_releaseId]].pricePerItem) {
            listings[_listingId].nextListingId = headListingIds[_releaseId];
            listings[headListingIds[_releaseId]].prevListingId = _listingId;
            headListingIds[_releaseId] = _listingId;
        } else if (_pricePerItem >= listings[tailListingIds[_releaseId]].pricePerItem) {
            listings[_listingId].prevListingId = tailListingIds[_releaseId];
            listings[tailListingIds[_releaseId]].nextListingId = _listingId;
            tailListingIds[_releaseId] = _listingId;
        } else {
            uint256 current = headListingIds[_releaseId];
            while (current != 0) {
                if (listings[current].pricePerItem > _pricePerItem) {
                    listings[_listingId].nextListingId = current;
                    listings[_listingId].prevListingId = listings[current].prevListingId;
                    listings[listings[current].prevListingId].nextListingId = _listingId;
                    listings[current].prevListingId = _listingId;
                    break;
                }
                current = listings[current].nextListingId;
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Fallback functions
    // ---------------------------------------------------------------------------

    /// @notice Fallback function to prevent direct Ether transfers
    fallback() external payable {
        revert SharedErrors.NotAllowed();
    }

    /// @notice Fallback function to prevent direct Ether transfers
    receive() external payable {
        revert SharedErrors.NotAllowed();
    }
}
