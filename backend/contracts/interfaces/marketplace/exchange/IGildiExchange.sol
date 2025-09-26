// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IGildiManager} from '../../manager/IGildiManager.sol';
import {IGildiPriceOracle} from '../../oracles/price/IGildiPriceOracle.sol';
import {IGildiExchangeOrderBook} from './IGildiExchangeOrderBook.sol';
import {IGildiExchangeFundManager} from './IGildiExchangeFundManager.sol';
import {IGildiExchangePaymentProcessor} from './IGildiExchangePaymentProcessor.sol';
import {IGildiExchangePaymentAggregator} from './IGildiExchangePaymentAggregator.sol';

/// @title IGildiExchange
/// @notice Interface for the Gildi Exchange.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiExchange is IAccessControl {
    /// @notice Represents a fee/burn receiver with an address and a basis points value and the currency to receive in.
    struct Receiver {
        /// @dev The address that receives the fee
        address receiverAddress;
        /// @dev The currency in which the fee is paid
        address payoutCurrency;
        /// @dev The value in basis points
        uint16 value;
    }

    /// @notice Represents a top-level fee distribution with an address and optional sub-fee receivers.
    struct FeeDistribution {
        /// @dev The primary fee receiver
        Receiver feeReceiver;
        /// @dev Used to distribute a portion of the parent fee, e.g., burn a fraction
        Receiver[] subFeeReceivers;
    }

    /// @notice Application environment settings
    struct AppEnvironment {
        /// @dev Application settings including dependencies
        AppSettings settings;
        /// @dev The basis points denominator for percentage calculations
        uint16 basisPoints;
        /// @dev The admin role identifier
        bytes32 adminRole;
        /// @dev The marketplace manager role identifier
        bytes32 marketplaceManagerRole;
        /// @dev The claimer role identifier
        bytes32 claimerRole;
    }

    /// @notice Application settings
    struct AppSettings {
        /// @dev The number of decimals for price asking
        uint8 priceAskDecimals;
        /// @dev The fee distribution structure
        FeeDistribution[] fees;
        /// @dev The marketplace currency
        IERC20 marketplaceCurrency;
        /// @dev The maximum number of buys per transaction
        uint256 maxBuyPerTransaction;
        /// @dev The Gildi manager interface
        IGildiManager gildiManager;
        /// @dev The order book interface
        IGildiExchangeOrderBook orderBook;
        /// @dev The price oracle interface
        IGildiPriceOracle gildiPriceOracle;
        /// @dev The fund manager interface
        IGildiExchangeFundManager fundManager;
        /// @dev The payment processor interface
        IGildiExchangePaymentProcessor paymentProcessor;
        /// @dev The payment aggregator interface
        IGildiExchangePaymentAggregator paymentAggregator;
    }

    /// @notice Purchases tokens of a release
    /// @dev Sweeps the floor
    /// @param _releaseId The ID of the release
    /// @param _amount The amount of tokens to purchase
    /// @param _maxTotalPrice The maximum total price to spend in Marketplace Currency
    /// @param _beneficiary The address to send the tokens to
    /// @param _isProxyOperation Whether the operation is a proxy operation
    /// @return amountSpent The amount of Marketplace Currency spent
    /// @return amountUsdSpent The amount spent in USD
    function purchase(
        uint256 _releaseId,
        uint256 _amount,
        uint256 _maxTotalPrice,
        address _beneficiary,
        bool _isProxyOperation
    ) external returns (uint256 amountSpent, uint256 amountUsdSpent);

    /// @notice Transfer a token in the context of the Gildi Exchange
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _value The amount to transfer
    /// @param _amountCurrency The currency of the amount
    function transferTokenInContext(address _from, address _to, uint256 _value, address _amountCurrency) external;

    /// @notice Tries to burn a token in the context of the Gildi Exchange
    /// @param _from The address to burn from
    /// @param _value The amount to burn
    /// @param _amountCurrency The currency of the amount
    /// @return Whether the burn was successful
    function tryBurnTokenInContext(address _from, uint256 _value, address _amountCurrency) external returns (bool);

    /// @notice Gets the price needed to pay in marketplace currency to buy `_amountToBuy` units of `_releaseId`.
    /// @param _releaseId The ID of the release
    /// @param _amountToBuy The amount of tokens to buy
    /// @param _buyer The address of the buyer (optional)
    /// @return totalPriceInCurrency The total cost in marketplace currency
    /// @return asset The asset the price is in
    /// @return totalPriceUsd The total price in USD (using exchange's priceAskDecimals)
    function quotePricePreview(
        uint256 _releaseId,
        uint256 _amountToBuy,
        address _buyer
    ) external view returns (uint256 totalPriceInCurrency, address asset, uint256 totalPriceUsd);

    /// @notice Checks if a release is currently in its initial sale period
    /// @param _releaseId The ID of the release
    /// @return True if the release is in active initial sale, false otherwise
    function isInInitialSale(uint256 _releaseId) external view returns (bool);

    /// @notice Returns the app environment.
    /// @return appEnvironment The app environment
    function getAppEnvironment() external view returns (AppEnvironment memory);

    /// @notice Gets the active marketplace asset for a release
    /// @param _releaseId The ID of the release
    /// @return The address of the active marketplace asset for the release
    function getActiveMarketplaceReleaseAsset(uint256 _releaseId) external view returns (address);

    /// @notice Get the fees of a specific release
    /// @param _releaseId The ID of the release
    /// @return An array of fee distributions for the release
    function getReleaseFees(uint256 _releaseId) external view returns (FeeDistribution[] memory);

    /// @notice Get a list of release IDs
    /// @param _activeOnly Whether or not to only return active releases
    /// @return activeReleases An array of release IDs
    function getReleaseIds(bool _activeOnly) external view returns (uint256[] memory);

    /// @notice Creates a listing with default slippage
    /// @param _releaseId The ID of the release
    /// @param _seller The address of the seller
    /// @param _pricePerItem The price per item in USD
    /// @param _quantity The quantity being listed
    /// @param _fundsReceiver The address to receive funds from the sale (if address(0), defaults to seller)
    /// @param _payoutCurrency The currency the seller wants to receive payment in
    function createListing(
        uint256 _releaseId,
        address _seller,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external;

    /// @notice Modifies a listing with default slippage
    /// @param _listingId The ID of the listing to modify
    /// @param _newPricePerItem The new price per item in USD
    /// @param _newQuantity The new quantity (if 0, the listing will be removed)
    /// @param _payoutCurrency The new payout currency
    /// @param _fundsReceiver The address to receive funds from the sale (if address(0), defaults to seller)
    function modifyListing(
        uint256 _listingId,
        uint256 _newPricePerItem,
        uint256 _newQuantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external;

    /// @notice Cancels a listing by ID
    /// @param _listingId The ID of the listing to cancel
    function cancelListing(uint256 _listingId) external;
}
