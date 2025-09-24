// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title SharedErrors
/// @notice Common error definitions shared across Gildi Exchange contracts
/// @dev This library consolidates error definitions to avoid duplication
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
library SharedErrors {
    /// @dev Emitted when a function parameter is invalid or out-of-range (e.g. zero batchSize, zero price, etc.)
    error ParamError();

    /// @dev Emitted when an operation is not allowed for the caller
    error NotAllowed();

    /// @dev Emitted when the caller is invalid
    error InvalidCaller();

    /// @dev Emitted when a listing ID is invalid or does not match storage data
    /// @param listingId The ID that caused the error
    error ListingError(uint256 listingId);
}
