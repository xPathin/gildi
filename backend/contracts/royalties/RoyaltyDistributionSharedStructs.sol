// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title RoyaltyDistributionSharedStructs
/// @notice Library for shared structs used in the Royalty Distribution.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
library RoyaltyDistributionSharedStructs {
    /// @notice A struct representing an asset value.
    struct AssetValue {
        /// @notice The address of the asset.
        address assetAddress;
        /// @notice The amount of the asset.
        uint256 amount;
    }

    /// @notice A struct representing a royalty claim.
    struct Claim {
        /// @notice The ID of the distribution.
        uint256 distributionId;
        /// @notice The address of the user.
        address user;
        /// @notice The asset values.
        AssetValue[] assetValues;
        /// @notice The shares of the user the values are based on.
        uint256 userShares;
        /// @notice The date and time when the claim was created.
        uint256 createdAt;
        /// @notice The claim was claimed (paid out).
        bool claimed;
    }
}
