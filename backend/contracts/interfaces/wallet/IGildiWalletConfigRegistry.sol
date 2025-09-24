// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

/// @title IGildiWalletConfigRegistry
/// @notice Interface for centralized configuration registry for all wallet instances
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IGildiWalletConfigRegistry {
    /// @notice Wallet configuration for marketplace integration
    struct WalletConfig {
        /// @dev Address of the GildiExchange contract
        address gildiExchangeV2;
        /// @dev Address of the RoyaltyDistributor contract
        address royaltyDistributor;
        /// @dev Address of the GildiManager contract
        address gildiManager;
        /// @dev Address of the PaymentAggregator contract for marketplace operations
        address paymentAggregator;
        /// @dev Address of the GildiExchangePurchaseVault contract for USD treasury operations
        address purchaseVault;
    }

    /// @dev Emitted when global configuration is updated
    event GlobalConfigUpdated(uint256 indexed version, WalletConfig config);

    /// @notice Sets configuration for a specific logic contract version
    /// @dev Only callable by accounts with CONFIG_MANAGER_ROLE. Version 0 is the default config.
    /// @param _version The logic contract version this config applies to (0 = default)
    /// @param _config The configuration for this version
    function setConfigForVersion(uint256 _version, WalletConfig calldata _config) external;

    /// @notice Gets configuration for a specific logic contract version
    /// @dev Returns the config for the specified version, or version 0 (default) if not found
    /// @param _version The logic contract version to get config for
    /// @return The configuration for this version
    function getConfigForVersion(uint256 _version) external view returns (WalletConfig memory);

    /// @notice Gets the default global configuration (version 0)
    /// @return config The default global configuration
    function getDefaultConfig() external view returns (WalletConfig memory config);

    /// @notice Checks if a configuration exists for a specific version
    /// @param _version The version to check
    /// @return exists Whether configuration exists for this version
    function hasConfigForVersion(uint256 _version) external view returns (bool exists);
}
