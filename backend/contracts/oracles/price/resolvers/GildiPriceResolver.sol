// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '../../../interfaces/oracles/price/IGildiPriceResolver.sol';
import '../../../interfaces/oracles/price/IGildiPriceOracle.sol';
import '../providers/GildiPriceProvider.sol';

import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/// @title Gildi Price Resolver
/// @notice Resolves prices using an external data source
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiPriceResolver is IGildiPriceResolver, Initializable, AccessControlUpgradeable {
    /// @notice The external data source for price data (could be another contract or oracle)
    GildiPriceProvider public dataSource;

    // Custom Errors
    /// @dev Thrown when the data source address is zero
    error DataSourceAddressZero();
    /// @dev Thrown when a pair is not found
    error PairNotFound();
    /// @dev Thrown when the oracle address is zero
    error OracleAddressZero();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the address of the external data source
    /// @param _gildiPriceProvider The address of the external data source
    /// @param _defaultAdmin The address of the default admin
    function initialize(GildiPriceProvider _gildiPriceProvider, address _defaultAdmin) external initializer {
        __AccessControl_init();

        if (address(_gildiPriceProvider) == address(0)) {
            revert DataSourceAddressZero();
        }
        dataSource = _gildiPriceProvider;
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /// @inheritdoc IGildiPriceResolver
    function getPrice(bytes32 _pairId) external view override returns (PriceData memory priceData) {
        return dataSource.getPrice(_pairId);
    }

    /// @inheritdoc IGildiPriceResolver
    function getPriceNoOlderThan(
        bytes32 _pairId,
        uint256 _age
    ) external view override returns (PriceData memory priceData) {
        return dataSource.getPriceNoOlderThan(_pairId, _age);
    }
}
