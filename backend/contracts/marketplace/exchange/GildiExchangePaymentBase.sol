// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../../interfaces/external/IWNative.sol';
import '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import '../../interfaces/marketplace/exchange/IGildiExchangePaymentAggregator.sol';
import './GildiExchangePaymentBaseCore.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/// @title GildiExchangePaymentBase
/// @notice Abstract base contract (non-upgradeable) implementing the payment flow for the marketplace.
/// @dev Inherits from Ownable and ReentrancyGuard.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
abstract contract GildiExchangePaymentBase is GildiExchangePaymentBaseCore, Context, AccessControl, ReentrancyGuard {
    // Regular storage variable for holding state.
    GildiExchangePaymentBaseStorage private $;

    /// @notice Constructor initializing the Gildi Exchange and Marketplace Token.
    /// @param _gildiExchange The address of the Gildi Exchange.
    /// @param _initialDefaultAdmin The address of the initial default admin.
    /// @param _initialContractAdmin The address of the initial contract admin.
    constructor(address _gildiExchange, address _initialDefaultAdmin, address _initialContractAdmin) {
        $.gildiExchange = IGildiExchange(_gildiExchange);

        _grantRole(DEFAULT_ADMIN_ROLE, _initialDefaultAdmin);
        _grantRole(ADMIN_ROLE, _initialContractAdmin);
    }

    //----- Admin Functions -----

    /// @notice Sets whether native payments are allowed for purchases.
    /// @param _allow True if native payments should be enabled.
    function setPurchaseAllowNative(bool _allow) public onlyRole(ADMIN_ROLE) {
        super._setPurchaseAllowNative(_allow);
    }

    /// @notice Sets the allowed purchase status for a given source token.
    /// @param _token The address of the token.
    /// @param _allowed True to allow the token.
    function setAllowedPurchaseToken(address _token, bool _allowed) external onlyRole(ADMIN_ROLE) {
        super._setAllowedPurchaseToken(_token, _allowed);
    }

    /// @notice Adds a new aggregator/DEX adapter.
    /// @param _adapter The adapter to add.
    function addAdapter(IGildiExchangeSwapAdapter _adapter) external onlyRole(ADMIN_ROLE) {
        super._addAdapter(_adapter);
    }

    /// @notice Removes an adapter by instance.
    /// @param adapter The adapter instance to remove.
    function removeAdapter(IGildiExchangeSwapAdapter adapter) external onlyRole(ADMIN_ROLE) {
        super._removeAdapter(adapter);
    }

    /// @notice Sets the wrapped native token address.
    /// @param _wnative The address of the wrapped native token.
    function setWrappedNative(address _wnative) external onlyRole(ADMIN_ROLE) {
        super._setWrappedNative(_wnative);
    }

    /// @notice Removes an adapter by its index.
    /// @param index The index of the adapter to remove.
    function removeAdapter(uint256 index) external onlyRole(ADMIN_ROLE) {
        super._removeAdapter(index);
    }

    //----- Internal Storage Getter -----

    /// @dev Returns the storage pointer for this contract.
    function _getStorage() internal view override returns (GildiExchangePaymentBaseStorage storage) {
        return $;
    }

    function _msgSender() internal view override(GildiExchangePaymentBaseCore, Context) returns (address sender) {
        return super._msgSender();
    }
}
