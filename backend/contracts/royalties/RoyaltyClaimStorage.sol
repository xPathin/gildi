// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../storage/AddressKeyValueStore.sol';
import './RoyaltyDistributionSharedStructs.sol';

/// @title RoyaltyClaimStorage
/// @notice A seperate contract to store the royalty claims.
/// @dev Deployed by the Royalty Distributor. Might be switched to an off-chain solution in the future.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract RoyaltyClaimStorage is AddressKeyValueStore {
    using RoyaltyDistributionSharedStructs for *;

    constructor(uint256 distributionId) AddressKeyValueStore(_msgSender()) {
        DISTRIBUTION_ID = distributionId;
    }

    /// @notice The ID of the Distribution.
    uint256 immutable DISTRIBUTION_ID;

    event ClaimDeleted(uint256 indexed releaseId, address indexed user);
    event ClaimPushed(
        uint256 indexed releaseId,
        address indexed user,
        address[] assets,
        uint256[] values,
        uint256 timestamp
    );

    /// @notice Sets a Claim for a user.
    /// @param _user The user address.
    /// @param _claim The new claim entry.
    function setClaim(address _user, RoyaltyDistributionSharedStructs.Claim calldata _claim) external {
        // Check if the user already has claims
        set(_user, claimToBytes(_claim));

        address[] memory assets = new address[](_claim.assetValues.length);
        uint256[] memory values = new uint256[](_claim.assetValues.length);
        for (uint256 i = 0; i < _claim.assetValues.length; i++) {
            assets[i] = _claim.assetValues[i].assetAddress;
            values[i] = _claim.assetValues[i].amount;
        }

        emit ClaimPushed(DISTRIBUTION_ID, _user, assets, values, block.timestamp);
    }

    /// @notice Checks if a user has a claim.
    /// @param _user The user address.
    /// @return Whether the user has a claim or not.
    function hasClaim(address _user) external view returns (bool) {
        return containsKey(_user);
    }

    /// @notice Fetch the claim of a user.
    /// @param _user The user address.
    /// @return The claim of the user.
    function fetchClaim(address _user) external view returns (RoyaltyDistributionSharedStructs.Claim memory) {
        bytes memory claimData = get(_user);
        return bytesToClaim(claimData);
    }

    /// @notice Fetch all claims.
    /// @return All claims.
    function fetchAllClaims() external view returns (RoyaltyDistributionSharedStructs.Claim[] memory) {
        RoyaltyDistributionSharedStructs.Claim[] memory claims = new RoyaltyDistributionSharedStructs.Claim[](
            getNumberOfKeys()
        );

        bytes[] memory allData = getAll();
        for (uint256 i = 0; i < allData.length; i++) {
            claims[i] = bytesToClaim(allData[i]);
        }

        return claims;
    }

    /// @notice Fetch the users.
    function fetchUsers() external view returns (address[] memory) {
        return getAllKeys();
    }

    function claimToBytes(RoyaltyDistributionSharedStructs.Claim memory _claim) private pure returns (bytes memory) {
        return abi.encode(_claim);
    }

    function bytesToClaim(bytes memory _data) private pure returns (RoyaltyDistributionSharedStructs.Claim memory) {
        RoyaltyDistributionSharedStructs.Claim memory res = abi.decode(_data, (RoyaltyDistributionSharedStructs.Claim));
        return res;
    }
}
