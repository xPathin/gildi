// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IGildiWalletConfigRegistry} from '../interfaces/wallet/IGildiWalletConfigRegistry.sol';

/// @title GildiWalletConfigRegistry
/// @notice Centralized configuration registry for all wallet instances
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiWalletConfigRegistry is Initializable, AccessControlUpgradeable, IGildiWalletConfigRegistry {
    /// @dev Thrown when GildiExchange address is zero
    error InvalidGildiExchangeAddress();

    /// @dev Thrown when RoyaltyDistributor address is zero
    error InvalidRoyaltyDistributorAddress();

    /// @dev Thrown when GildiManager address is zero
    error InvalidGildiManagerAddress();

    /// @notice Emitted when the registry is initialized
    /// @param defaultAdmin The address that received DEFAULT_ADMIN_ROLE
    /// @param configManager The address that received CONFIG_MANAGER_ROLE
    /// @param defaultConfig The default configuration set during initialization
    event RegistryInitialized(address indexed defaultAdmin, address indexed configManager, WalletConfig defaultConfig);

    /// @notice Role identifier for configuration managers
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256('CONFIG_MANAGER_ROLE');

    /// @notice Configuration storage by version (version 0 = default)
    mapping(uint256 => WalletConfig) public configByVersion;

    /// @notice Array of versions that have configs, kept in ascending order
    uint256[] private configVersions;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the configuration registry
    /// @dev Can only be called once during deployment
    /// @param _defaultAdmin The address that will receive the DEFAULT_ADMIN_ROLE
    /// @param _configManager The address that will receive the CONFIG_MANAGER_ROLE
    /// @param _defaultConfig The default configuration for all wallets
    function initialize(
        address _defaultAdmin,
        address _configManager,
        WalletConfig calldata _defaultConfig
    ) public initializer {
        if (_defaultConfig.gildiExchangeV2 == address(0)) {
            revert InvalidGildiExchangeAddress();
        }
        if (_defaultConfig.royaltyDistributor == address(0)) {
            revert InvalidRoyaltyDistributorAddress();
        }
        if (_defaultConfig.gildiManager == address(0)) {
            revert InvalidGildiManagerAddress();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        if (_configManager != address(0)) {
            _grantRole(CONFIG_MANAGER_ROLE, _configManager);
        }

        configByVersion[0] = _defaultConfig;
        configVersions.push(0); // Initialize with version 0

        emit RegistryInitialized(_defaultAdmin, _configManager, _defaultConfig);
    }

    /// @notice Sets configuration for a specific logic contract version
    /// @dev Only callable by accounts with CONFIG_MANAGER_ROLE. Version 0 is the default config.
    /// @param _version The logic contract version this config applies to (0 = default)
    /// @param _config The configuration for this version
    function setConfigForVersion(
        uint256 _version,
        WalletConfig calldata _config
    ) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_config.gildiExchangeV2 == address(0)) {
            revert InvalidGildiExchangeAddress();
        }
        if (_config.royaltyDistributor == address(0)) {
            revert InvalidRoyaltyDistributorAddress();
        }
        if (_config.gildiManager == address(0)) {
            revert InvalidGildiManagerAddress();
        }

        // Check if this is a new version
        bool isNewVersion = configByVersion[_version].gildiExchangeV2 == address(0);

        configByVersion[_version] = _config;

        // Add to sorted versions array if new
        if (isNewVersion && _version != 0) {
            // version 0 is already added during initialization
            _insertVersionSorted(_version);
        }

        emit GlobalConfigUpdated(_version, _config);
    }

    /// @notice Gets configuration for a specific logic contract version
    /// @dev Returns the best available config: highest version <= requested version, or version 0 (default) if none found
    /// @param _version The logic contract version to get config for
    /// @return The best available configuration for this version range
    function getConfigForVersion(uint256 _version) external view returns (WalletConfig memory) {
        // First try exact match
        WalletConfig memory config = configByVersion[_version];
        if (config.gildiExchangeV2 != address(0)) {
            return config;
        }

        // Find the highest version <= _version that has a config
        // Iterate through sorted versions array (much more efficient)
        uint256 bestVersion = 0; // Default to version 0
        for (uint256 i = 0; i < configVersions.length; i++) {
            uint256 candidateVersion = configVersions[i];
            if (candidateVersion <= _version) {
                bestVersion = candidateVersion;
            } else {
                // Array is sorted, so no need to continue
                break;
            }
        }

        return configByVersion[bestVersion];
    }

    /// @notice Gets the default global configuration (version 0)
    /// @return config The default global configuration
    function getDefaultConfig() external view returns (WalletConfig memory config) {
        return configByVersion[0];
    }

    /// @notice Checks if a configuration exists for a specific version
    /// @param _version The version to check
    /// @return exists Whether configuration exists for this version
    function hasConfigForVersion(uint256 _version) external view returns (bool exists) {
        return configByVersion[_version].gildiExchangeV2 != address(0);
    }

    /// @notice Gets all configured versions
    /// @return versions Array of all versions that have configurations
    function getConfiguredVersions() external view returns (uint256[] memory versions) {
        return configVersions;
    }

    /// @dev Internal function to insert a version into the sorted array
    /// @param _version The version to insert
    function _insertVersionSorted(uint256 _version) private {
        // Find insertion point
        uint256 insertIndex = configVersions.length;
        for (uint256 i = 0; i < configVersions.length; i++) {
            if (configVersions[i] > _version) {
                insertIndex = i;
                break;
            }
        }

        // Add element and shift if necessary
        configVersions.push(0); // Expand array
        for (uint256 i = configVersions.length - 1; i > insertIndex; i--) {
            configVersions[i] = configVersions[i - 1];
        }
        configVersions[insertIndex] = _version;
    }
}
