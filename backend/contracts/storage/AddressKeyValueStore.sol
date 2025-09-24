// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import './base/KeyValueStore.sol';

/// @title Address key value store contract.
/// @notice This contract allows an owner to store, retrieve, and delete arbitrary data by an address key.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract AddressKeyValueStore is KeyValueStore {
    constructor(address _owner) KeyValueStore(_owner) {}

    /// @notice Gets the data stored against the given key.
    /// @param _key The key to get the data for.
    /// @return The data stored against the given key.
    function get(address _key) internal view returns (bytes memory) {
        return _get(addressToBytes32(_key));
    }

    /// notice Gets the key at the given index.
    /// @param _index The index of the key to get.
    /// @return The key at the given index.
    function getKeyAtIndex(uint256 _index) internal view returns (address) {
        return bytes32ToAddress(_getKeyAtIndex(_index));
    }

    /// @notice Gets all the data stored in the store.
    /// @return All the data stored in the store.
    function getAll() internal view returns (bytes[] memory) {
        return _getAll();
    }

    /// @notice Gets all the keys used in the store.
    /// @return All the keys used in the store.
    function getAllKeys() internal view returns (address[] memory) {
        bytes32[] memory keys = _getAllKeys();
        address[] memory addressKeys = new address[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            addressKeys[i] = bytes32ToAddress(keys[i]);
        }
        return addressKeys;
    }

    /// @notice Gets the number of keys used in the store.
    /// @return The number of keys used in the store.
    function getNumberOfKeys() internal view returns (uint256) {
        return _getNumberOfKeys();
    }

    /// @notice Checks if the given key exists in the store.
    /// @param _key The key to check for existence.
    function containsKey(address _key) internal view returns (bool) {
        return _containsKey(addressToBytes32(_key));
    }

    /// @notice Sets the given value against the given key.
    function set(address _key, bytes memory _value) internal {
        _set(addressToBytes32(_key), _value);
    }

    /// @notice Deletes the data stored against the given key.
    function del(address _key) internal {
        _del(addressToBytes32(_key));
    }

    /// @inheritdoc KeyValueStore
    function _initialize() internal virtual override initializeOnlyOnce {}

    function bytes32ToAddress(bytes32 byteData) private pure returns (address) {
        return address(uint160(uint256(byteData)));
    }

    function addressToBytes32(address addr) private pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
