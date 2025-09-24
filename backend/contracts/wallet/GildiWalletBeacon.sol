// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IBeacon} from '@openzeppelin/contracts/proxy/beacon/IBeacon.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';

/// @title GildiWalletBeacon
/// @notice Beacon contract that manages the implementation address for wallet proxies
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiWalletBeacon is IBeacon, AccessControl {
    /// @notice Role identifier for accounts that can upgrade the implementation
    bytes32 public constant UPGRADER_ROLE = keccak256('UPGRADER_ROLE');

    /// @dev The current implementation address
    address private implementationAddress;

    /// @dev Thrown when attempting to set an invalid implementation address
    error BeaconInvalidImplementation(address implementation);

    /// @dev Thrown when attempting to initialize with a zero address for default admin
    error ZeroDefaultAdminAddress();

    /// @dev Thrown when attempting to initialize with a zero address for initial upgrader
    error ZeroInitialUpgraderAddress();

    /// @notice Emitted when the implementation is upgraded
    event BeaconUpgraded(address indexed implementation);

    /// @notice Initializes the beacon with an implementation and role assignments
    /// @param _initialImplementation The initial implementation contract address
    /// @param _defaultAdmin The address that will receive the DEFAULT_ADMIN_ROLE
    /// @param _initialUpgrader The address that will receive the UPGRADER_ROLE
    constructor(address _initialImplementation, address _defaultAdmin, address _initialUpgrader) {
        if (_defaultAdmin == address(0)) {
            revert ZeroDefaultAdminAddress();
        }
        if (_initialUpgrader == address(0)) {
            revert ZeroInitialUpgraderAddress();
        }

        _setImplementation(_initialImplementation);

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _initialUpgrader);
    }

    /// @notice Returns the current implementation address
    /// @return The address of the current implementation contract
    function implementation() public view virtual returns (address) {
        return implementationAddress;
    }

    /// @notice Upgrades the beacon to a new implementation
    /// @dev Only callable by accounts with UPGRADER_ROLE
    /// @param _newImplementation The address of the new implementation contract
    function upgradeTo(address _newImplementation) public onlyRole(UPGRADER_ROLE) {
        _setImplementation(_newImplementation);
    }

    /// @dev Sets the implementation address after validating it has code
    /// @param _newImplementation The new implementation address to set
    function _setImplementation(address _newImplementation) private {
        if (_newImplementation.code.length == 0) {
            revert BeaconInvalidImplementation(_newImplementation);
        }
        implementationAddress = _newImplementation;
        emit BeaconUpgraded(_newImplementation);
    }
}
