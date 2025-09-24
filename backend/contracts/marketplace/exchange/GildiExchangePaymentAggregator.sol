// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import './GildiExchangePaymentBaseUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/// @title GildiExchangePaymentAggregator
/// @notice A generic payment adapter that aggregates multiple DEX/aggregator adapters.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiExchangePaymentAggregator is GildiExchangePaymentBaseUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the aggregator with the exchange, marketplace token, and wrapped native token.
    /// @param _gildiExchange The address of the Gildi Exchange.
    /// @param _wNativeAddress The address of the wrapped native token.
    /// @param _initialDefaultAdmin The address of the initial default admin.
    /// @param _initialContractAdmin The address of the initial contract admin.
    function initialize(
        address _gildiExchange,
        address _wNativeAddress,
        address _initialDefaultAdmin,
        address _initialContractAdmin
    ) public initializer {
        __GildiExchangePaymentBase_init(_gildiExchange, _initialDefaultAdmin, _initialContractAdmin);
        _setPurchaseAllowNative(true);
        _setWrappedNative(_wNativeAddress);
    }
}
