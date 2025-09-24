// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../storage/AddressKeyValueStore.sol';

/// @title GildiManagerOwnershipStorage
/// @notice A seperate contract to store the ownership inside the Gildi Manager.
/// @dev Deployed by the Gildi Manager. Might be switched to an off-chain solution in the future.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract GildiManagerOwnershipStorage is AddressKeyValueStore {
    constructor(uint256 releaseId, uint256 timePeriod) AddressKeyValueStore(_msgSender()) {
        TIME_PERIOD = timePeriod < 10 minutes ? 10 minutes : timePeriod;
        RELEASE_ID = releaseId;
    }

    /// @notice The time period in which we calculate the shares owned by a user.
    uint256 public immutable TIME_PERIOD;
    /// @notice The ID of the Royalty Rights Token / release.
    uint256 immutable RELEASE_ID;

    /// @notice The ownership of a user for a specific RWA.
    struct Ownership {
        /// @notice The amount owned by the user.
        uint256 amount;
        /// @notice The timestamp of the last update.
        uint256 timestamp;
    }

    event OwnershipUpdated(uint256 indexed releaseId, address indexed user, uint256 amount, uint256 timestamp);
    event OwnershipDeleted(uint256 indexed releaseId, address indexed user);
    event OwnershipPushed(uint256 indexed releaseId, address indexed user, uint256 amount, uint256 timestamp);

    /// @notice Delete the ownerships of a user.
    /// @param _user The user address.
    function deleteOwnerships(address _user) external {
        del(_user);
        emit OwnershipDeleted(RELEASE_ID, _user);
    }

    /// @notice Push a new ownership entry for a user.
    /// @param _user The user address.
    /// @param _ownership The new ownership entry.
    function pushOwnership(address _user, Ownership calldata _ownership) external {
        // Check if the user already has ownerships
        Ownership[] memory oldOwnerships = new Ownership[](0);
        if (containsKey(_user)) {
            oldOwnerships = bytesToOwnerships(get(_user));
        }

        Ownership[] memory newOwnerships = new Ownership[](oldOwnerships.length + 1);
        for (uint256 i = 0; i < oldOwnerships.length; i++) {
            newOwnerships[i] = oldOwnerships[i];
        }
        newOwnerships[oldOwnerships.length] = _ownership;
        set(_user, ownershipsToBytes(newOwnerships));

        emit OwnershipPushed(RELEASE_ID, _user, _ownership.amount, _ownership.timestamp);
    }

    /// @notice Update an ownership entry for a user at a specific index.
    /// @param _user The user address.
    /// @param _index The index of the ownership entry.
    /// @param _ownership The updated ownership entry.
    function updateOwnershipEntry(address _user, uint256 _index, Ownership calldata _ownership) external {
        Ownership[] memory ownerships = new Ownership[](0);

        if (containsKey(_user)) {
            ownerships = bytesToOwnerships(get(_user));
        }
        if (_index >= ownerships.length) {
            revert IndexOutOfBounds(_index);
        }
        ownerships[_index] = _ownership;
        set(_user, ownershipsToBytes(ownerships));

        emit OwnershipUpdated(RELEASE_ID, _user, _ownership.amount, _ownership.timestamp);
    }

    /// @notice Fetch the ownership of a user.
    /// @param _user The user address.
    function fetchOwnerships(address _user) external view returns (Ownership[] memory) {
        if (!containsKey(_user)) {
            return new Ownership[](0);
        }
        bytes memory allData = get(_user);
        return bytesToOwnerships(allData);
    }

    /// @notice Fetch the users.
    function fetchUsers() external view returns (address[] memory) {
        return getAllKeys();
    }

    function ownershipsToBytes(Ownership[] memory _ownership) private pure returns (bytes memory) {
        return abi.encode(_ownership);
    }

    function bytesToOwnerships(bytes memory _data) private pure returns (Ownership[] memory) {
        Ownership[] memory res = abi.decode(_data, (Ownership[]));
        return res;
    }
}
