// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {IBeacon} from '@openzeppelin/contracts/proxy/beacon/IBeacon.sol';
import {StorageSlot} from '@openzeppelin/contracts/utils/StorageSlot.sol';

/// @title GildiWalletBeaconProxy
/// @notice BeaconProxy with additional functionality like freezing implementation and setting a custom implementation. Uses a simple owner/operator pattern.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiWalletBeaconProxy is BeaconProxy {
    /// @dev Storage slots (EIP-1967 style) for proxy-specific state to avoid collisions with implementation
    bytes32 private constant OWNER_SLOT = 0x7b9de4d5208379c574cec2d635a21aa5e97ccefb6169355a0c4aeb66af8d11e7;
    bytes32 private constant OPERATOR_SLOT = 0x95f03cd5bcea7edcde1ad4dffbf6580386ba9217c5aaeb6372a784f41c1f21a3;
    bytes32 private constant OPERATOR_REVOKED_SLOT = 0x2bad8861766d5ce4c5c51525728286895174f7d076c90f3066eca92fff25bfea;
    bytes32 private constant FROZEN_SLOT = 0x858a9ce43794e55f03c1c5fc02176a6882a143de4d9829430a832144e5714486;
    bytes32 private constant FROZEN_IMPL_SLOT = 0xc93e0c4c416d4714086268bbe76236443e520ba92d7861ebf106854c6bbdc1ae;
    bytes32 private constant CUSTOM_IMPL_SLOT = 0xcf3cd2e0b8b185268580bdc8fe9cc97acf4a8b998dc8901aa169913239f1858f;
    /// @dev Off-ramp guard slot to allow logic to verify call path originates from this proxy flow
    bytes32 private constant OFFRAMP_GUARD_SLOT = 0xbf2e87ae6cef65f01e1c587276c96bbd9fc7ff1493647120ef7d93bf473a6640;

    /// @dev Thrown when caller is not the owner
    error NotOwner();

    /// @dev Thrown when caller is neither owner nor operator
    error NotOwnerOrOperator();

    /// @dev Thrown when caller is not the operator
    error NotOperator();

    /// @dev Thrown when attempting to initialize with zero owner address
    error ZeroOwnerAddress();

    /// @dev Thrown when implementation is already frozen
    error ImplementationAlreadyFrozen();

    /// @dev Thrown when implementation is not frozen
    error ImplementationNotFrozen();

    /// @dev Thrown when attempting to set zero address as custom implementation
    error ZeroCustomImplementationAddress();

    /// @dev Thrown when operator is already revoked
    error OperatorAlreadyRevoked();

    /// @dev Thrown when custom implementation is set during operator revocation
    error CustomImplementationSet();

    /// @dev Thrown when attempting to transfer ownership to zero address
    error ZeroNewOwnerAddress();

    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /// @notice Emitted when the operator is changed
    event GildiOperatorChanged(address indexed previousOperator, address indexed newOperator);
    /// @notice Emitted when the implementation is frozen with the frozen implementation address
    event ImplementationFrozen(address indexed implementation);
    /// @notice Emitted when the implementation is unfrozen
    event ImplementationUnfrozen();
    /// @notice Emitted when a custom implementation is set
    event CustomImplementationConfigured(address indexed implementation);
    /// @notice Emitted when the custom implementation is unset
    event CustomImplementationUnset();
    /// @notice Emitted when the operator revokes itself
    event GildiOperatorRevoked(address indexed operator);

    // =========================
    // Internal storage helpers
    // =========================

    /// @dev Returns the current owner address from storage
    function _owner() internal view returns (address) {
        return StorageSlot.getAddressSlot(OWNER_SLOT).value;
    }

    /// @dev Sets the owner address in storage
    function _setOwner(address _newOwner) internal {
        StorageSlot.getAddressSlot(OWNER_SLOT).value = _newOwner;
    }

    /// @dev Returns the current operator address from storage
    function _operator() internal view returns (address) {
        return StorageSlot.getAddressSlot(OPERATOR_SLOT).value;
    }

    /// @dev Sets the operator address in storage
    function _setOperator(address _newOperator) internal {
        StorageSlot.getAddressSlot(OPERATOR_SLOT).value = _newOperator;
    }

    /// @dev Returns whether the operator has been revoked
    function _isOperatorRevoked() internal view returns (bool) {
        return StorageSlot.getBooleanSlot(OPERATOR_REVOKED_SLOT).value;
    }

    /// @dev Sets the operator revoked status in storage
    function _setOperatorRevoked(bool _revoked) internal {
        StorageSlot.getBooleanSlot(OPERATOR_REVOKED_SLOT).value = _revoked;
    }

    /// @dev Returns whether the implementation is frozen
    function _isFrozen() internal view returns (bool) {
        return StorageSlot.getBooleanSlot(FROZEN_SLOT).value;
    }

    /// @dev Sets the frozen status in storage
    function _setFrozen(bool _value) internal {
        StorageSlot.getBooleanSlot(FROZEN_SLOT).value = _value;
    }

    /// @dev Returns the frozen implementation address from storage
    function _frozenImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(FROZEN_IMPL_SLOT).value;
    }

    /// @dev Sets the frozen implementation address in storage
    function _setFrozenImplementation(address _impl) internal {
        StorageSlot.getAddressSlot(FROZEN_IMPL_SLOT).value = _impl;
    }

    /// @dev Returns the custom implementation address from storage
    function _customImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(CUSTOM_IMPL_SLOT).value;
    }

    /// @dev Sets the custom implementation address in storage
    function _setCustomImplementation(address _impl) internal {
        StorageSlot.getAddressSlot(CUSTOM_IMPL_SLOT).value = _impl;
    }

    /// @dev Returns the off-ramp guard status from storage
    function _offRampGuard() internal view returns (bool) {
        return StorageSlot.getBooleanSlot(OFFRAMP_GUARD_SLOT).value;
    }

    /// @dev Sets the off-ramp guard status in storage
    function _setOffRampGuard(bool _v) internal {
        StorageSlot.getBooleanSlot(OFFRAMP_GUARD_SLOT).value = _v;
    }

    // Modifiers
    /// @dev Restricts function access to the owner
    modifier onlyOwner() {
        if (msg.sender != _owner()) {
            revert NotOwner();
        }
        _;
    }

    /// @dev Restricts function access to either the owner or operator
    modifier onlyOwnerOrOperator() {
        address currentOwner = _owner();
        address currentOperator = _operator();
        if (msg.sender != currentOwner && msg.sender != currentOperator) {
            revert NotOwnerOrOperator();
        }
        _;
    }

    /// @dev Restricts function access to only the operator
    modifier onlyGildiOperator() {
        if (msg.sender != _operator()) {
            revert NotOperator();
        }
        _;
    }

    /// @notice Initializes the proxy with beacon, initialization data, owner, and operator
    /// @param _beacon The address of the beacon contract
    /// @param _data Initialization data to pass to the implementation
    /// @param _ownerAddress The address that will be set as the owner
    /// @param _operatorAddress The address that will be set as the operator
    constructor(
        address _beacon,
        bytes memory _data,
        address _ownerAddress,
        address _operatorAddress
    ) BeaconProxy(_beacon, _data) {
        if (_ownerAddress == address(0)) {
            revert ZeroOwnerAddress();
        }
        _setOwner(_ownerAddress);
        _setOperator(_operatorAddress);
    }

    /// @notice Freezes the current implementation to prevent beacon upgrades
    /// @dev Only callable by owner or operator
    function freezeImplementation() public onlyOwnerOrOperator {
        if (_isFrozen()) {
            revert ImplementationAlreadyFrozen();
        }
        _setFrozen(true);
        address impl = IBeacon(_getBeacon()).implementation();
        _setFrozenImplementation(impl);
        emit ImplementationFrozen(impl);
    }

    /// @notice Unfreezes the implementation to allow beacon upgrades
    /// @dev Only callable by owner or operator
    function unfreezeImplementation() public onlyOwnerOrOperator {
        if (!_isFrozen()) {
            revert ImplementationNotFrozen();
        }
        _setFrozen(false);
        emit ImplementationUnfrozen();
    }

    /// @notice Sets a custom implementation address that overrides the beacon
    /// @dev Only callable by owner or operator
    /// @param _newImplementation The address of the custom implementation
    function setCustomImplementation(address _newImplementation) external onlyOwnerOrOperator {
        if (_newImplementation == address(0)) {
            revert ZeroCustomImplementationAddress();
        }
        _setCustomImplementation(_newImplementation);
        emit CustomImplementationConfigured(_newImplementation);
    }

    /// @notice Removes the custom implementation to use the beacon again
    /// @dev Only callable by owner or operator
    function unsetCustomImplementation() external onlyOwnerOrOperator {
        _setCustomImplementation(address(0));
        emit CustomImplementationUnset();
    }

    /// @notice Changes the operator address
    /// @dev Only callable by the owner or current operator (for compromise scenarios)
    /// @param _newOperator The new operator address
    function changeGildiOperator(address _newOperator) public onlyOwnerOrOperator {
        address oldOperator = _operator();
        _setOperator(_newOperator);

        // Sync operator role in logic via delegatecall
        address impl = _implementation();
        _setOffRampGuard(true);
        (bool ok, ) = impl.delegatecall(
            abi.encodeWithSignature('offRampUpdateOperator(address,address)', oldOperator, _newOperator)
        );
        _setOffRampGuard(false);
        // intentionally ignore `ok` to ensure operator change continues even if logic signature changes/removed
        ok;

        emit GildiOperatorChanged(oldOperator, _newOperator);
    }

    /// @notice Revokes the operator and freezes the implementation
    /// @dev Only callable by owner or operator. Also removes operator role from the logic contract.
    function revokeOperator() external onlyOwnerOrOperator {
        if (_isOperatorRevoked()) {
            revert OperatorAlreadyRevoked();
        }
        if (_customImplementation() != address(0)) {
            revert CustomImplementationSet();
        }

        address oldOperator = _operator();

        // Remove operator privileges in logic via delegatecall to current implementation
        if (oldOperator != address(0)) {
            address impl = _implementation();
            _setOffRampGuard(true);
            (bool ok, ) = impl.delegatecall(abi.encodeWithSignature('offRampOperator(address)', oldOperator));
            _setOffRampGuard(false);
            // intentionally ignore `ok` to ensure revoke continues even if logic signature changes/removed
            ok;
        }

        _setOperatorRevoked(true);
        _setOperator(address(0));

        // Freeze the implementation when revoking
        if (!_isFrozen()) {
            freezeImplementation();
        }

        emit GildiOperatorRevoked(oldOperator);
    }

    /// @notice Transfers ownership to a new address
    /// @dev Only callable by the current owner. Also updates DEFAULT_ADMIN_ROLE in logic.
    /// @param _newOwner The address to transfer ownership to
    function transferOwnership(address _newOwner) public onlyOwner {
        if (_newOwner == address(0)) {
            revert ZeroNewOwnerAddress();
        }
        address oldOwner = _owner();
        _setOwner(_newOwner);

        // Sync admin role in logic via delegatecall
        address impl = _implementation();
        _setOffRampGuard(true);
        (bool ok, ) = impl.delegatecall(
            abi.encodeWithSignature('offRampUpdateAdmin(address,address)', oldOwner, _newOwner)
        );
        _setOffRampGuard(false);
        // intentionally ignore `ok` to ensure ownership transfer continues even if logic signature changes/removed
        ok;

        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    /// @inheritdoc BeaconProxy
    function _implementation() internal view override returns (address) {
        // Custom implementation takes precedence
        address customImpl = _customImplementation();
        if (customImpl != address(0)) {
            return customImpl;
        }

        // If frozen, use the frozen implementation
        if (_isFrozen()) {
            return _frozenImplementation();
        }

        // Otherwise, follow the beacon normally
        return super._implementation();
    }

    /// @notice Get the implementation address from the beacon
    /// @return The beacon's current implementation address
    function getBeaconImplementation() external view returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /// @notice Returns the address of the current owner
    /// @return The owner address
    function owner() external view returns (address) {
        return _owner();
    }

    /// @notice Returns the address of the gildiOperator
    /// @return The operator address
    function getOperator() external view returns (address) {
        return _operator();
    }

    /// @notice Check if operator is revoked
    /// @return True if the operator has been revoked, false otherwise
    function isOperatorRevoked() external view returns (bool) {
        return _isOperatorRevoked();
    }

    /// @notice Check if implementation is frozen
    /// @return True if the implementation is frozen, false otherwise
    function isFrozen() external view returns (bool) {
        return _isFrozen();
    }

    /// @notice Get the frozen implementation address
    /// @return The frozen implementation address
    function getFrozenImplementation() external view returns (address) {
        return _frozenImplementation();
    }

    /// @notice Get the custom implementation address
    /// @return The custom implementation address
    function getCustomImplementation() external view returns (address) {
        return _customImplementation();
    }

    /// @dev Receive function to handle direct Ether transfers
    receive() external payable virtual {
        _fallback();
    }
}
