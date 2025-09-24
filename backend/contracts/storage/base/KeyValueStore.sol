// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/// @title Store base contract.
/// @notice This contract allows an owner to store, retrieve, and delete arbitrary data by an arbitrary key.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
abstract contract KeyValueStore is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice Mapping that holds the stored data against their keys.
    mapping(bytes32 => bytes) internal data;

    /// @notice Set that keeps track of all keys used.
    EnumerableSet.Bytes32Set internal keys;

    /// @notice Whether the store has been initialized or not.
    bool private _initialized;

    /// @notice Emitted when data is added to the store.
    event DataAdded(bytes32 key);

    /// @notice Emitted when data is updated in the store.
    event DataUpdated(bytes32 key);

    /// @notice Emitted when data is deleted from the store.
    event DataDeleted(bytes32 key);

    /// @notice Emitted when the store is already initialized.
    error AlreadyInitialized();

    /// @notice Emitted when the key does not exist in the store.
    error KeyNotExists(bytes32 key);

    /// @notice Emitted when the index is out of bounds.
    error IndexOutOfBounds(uint256 index);

    /// @dev Initializes a new instance of the Store contract with the given owner.
    /// @param _owner The address of the owner of the Store contract.
    constructor(address _owner) Ownable(_owner) {
        _initialize();
    }

    /// @notice Gets the data stored against the given key.
    /// @param _key The key to get the data for.
    /// @return The data stored against the given key.
    function _get(bytes32 _key) internal view returns (bytes memory) {
        if (!keys.contains(_key)) {
            revert KeyNotExists(_key);
        }
        return data[_key];
    }

    /// notice Gets the key at the given index.
    /// @param _index The index of the key to get.
    /// @return The key at the given index.
    function _getKeyAtIndex(uint256 _index) internal view returns (bytes32) {
        if (_index >= keys.length()) {
            revert IndexOutOfBounds(_index);
        }
        return keys.at(_index);
    }

    /// @notice Gets all the data stored in the store.
    /// @return All the data stored in the store.
    function _getAll() internal view returns (bytes[] memory) {
        uint256 length = keys.length();
        bytes[] memory result = new bytes[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[keys.at(i)];
        }
        return result;
    }

    /// @notice Gets all the keys used in the store.
    /// @return All the keys used in the store.
    function _getAllKeys() internal view returns (bytes32[] memory) {
        return keys.values();
    }

    /// @notice Gets the number of keys used in the store.
    /// @return The number of keys used in the store.
    function _getNumberOfKeys() internal view returns (uint256) {
        return keys.length();
    }

    /// @notice Checks if the given key exists in the store.
    /// @param _key The key to check for existence.
    function _containsKey(bytes32 _key) internal view returns (bool) {
        return keys.contains(_key);
    }

    /// @notice Sets the given value against the given key.
    function _set(bytes32 _key, bytes memory _value) internal onlyOwner {
        bool isNewKey = !keys.contains(_key);
        if (isNewKey) {
            keys.add(_key);
            emit DataAdded(_key);
        } else {
            emit DataUpdated(_key);
        }
        data[_key] = _value;
    }

    /// @notice Deletes the data stored against the given key.
    function _del(bytes32 _key) internal onlyOwner {
        if (!keys.contains(_key)) {
            revert KeyNotExists(_key);
        }
        keys.remove(_key);
        delete data[_key];
        emit DataDeleted(_key);
    }

    /// @notice Initializes the store.
    /// @dev This function is called only once during the contract deployment.
    function _initialize() internal virtual initializeOnlyOnce {}

    // Modifier to make it impossible to call initialize twice
    modifier initializeOnlyOnce() {
        if (_initialized) {
            revert AlreadyInitialized();
        }
        _;
        _initialized = true;
    }
}
