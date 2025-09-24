// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {GildiWalletBeaconProxy} from './GildiWalletBeaconProxy.sol';

/// @title GildiWalletBeaconProxyFactory
/// @notice Factory for creating new GildiWalletBeaconProxy instances with external ID support for backend integration
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiWalletBeaconProxyFactory is Initializable, AccessControlUpgradeable {
    /// @notice Role identifier for accounts that can deploy new proxies
    bytes32 public constant DEPLOYER_ROLE = keccak256('DEPLOYER_ROLE');

    /// @dev The address of the beacon used for deployed proxies
    address private _beacon;
    /// @dev Array of all deployed proxy addresses
    address[] private _deployedProxies;
    /// @dev Mapping to check if an address is a deployed proxy
    mapping(address => bool) private _isProxyDeployed;

    /// @dev Thrown when attempting to initialize or set beacon with zero address
    error ZeroBeaconAddress();

    /// @dev Thrown when attempting to deploy proxy with zero owner address
    error ZeroOwnerAddress();

    /// @dev Thrown when attempting to initialize with zero admin address
    error ZeroAdminAddress();

    /// @dev Thrown when attempting to initialize with zero deployer address
    error ZeroDeployerAddress();

    /// @notice Emitted when a new proxy is deployed
    /// @dev Includes externalId for backend system integration
    event ProxyDeployed(
        address indexed proxyAddress,
        address indexed owner,
        address gildiOperator,
        string indexed externalId
    );
    /// @notice Emitted when the beacon address is updated
    event BeaconUpdated(address indexed previousBeacon, address indexed newBeacon);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the beacon address and sets up roles
    /// @dev This function can only be called once due to the initializer modifier
    /// @param _beaconAddress The address of the UpgradeableBeacon
    /// @param _initialDefaultAdmin The address to grant DEFAULT_ADMIN_ROLE
    /// @param _initialDeployer The address to grant DEPLOYER_ROLE
    function initialize(
        address _beaconAddress,
        address _initialDefaultAdmin,
        address _initialDeployer
    ) external initializer {
        if (_beaconAddress == address(0)) {
            revert ZeroBeaconAddress();
        }
        if (_initialDefaultAdmin == address(0)) {
            revert ZeroAdminAddress();
        }
        if (_initialDeployer == address(0)) {
            revert ZeroDeployerAddress();
        }
        __AccessControl_init();

        _beacon = _beaconAddress;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialDefaultAdmin);
        _grantRole(DEPLOYER_ROLE, _initialDeployer);
    }

    /// @notice Updates the beacon address
    /// @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
    /// @param _newBeacon The new beacon address
    function setBeacon(address _newBeacon) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newBeacon == address(0)) {
            revert ZeroBeaconAddress();
        }
        address oldBeacon = _beacon;
        _beacon = _newBeacon;
        emit BeaconUpdated(oldBeacon, _newBeacon);
    }

    /// @notice Returns the beacon address
    /// @return The current beacon address
    function beacon() external view returns (address) {
        return _beacon;
    }

    /// @notice Deploys a new proxy with owner, gildiOperator, and external ID
    /// @dev Only callable by accounts with DEPLOYER_ROLE
    /// @param _owner The owner address for the new proxy
    /// @param _gildiOperator The gildiOperator address for the new proxy
    /// @param _externalId The external identifier for backend system integration
    /// @return proxyAddress The address of the deployed proxy
    function deployProxy(
        address _owner,
        address _gildiOperator,
        address _configRegistry,
        string calldata _externalId
    ) external onlyRole(DEPLOYER_ROLE) returns (address proxyAddress) {
        if (_owner == address(0)) {
            revert ZeroOwnerAddress();
        }

        // Prepare initialization data for the LogicContract
        bytes memory initData = abi.encodeWithSignature(
            'initialize(address,address,address)',
            _owner,
            _gildiOperator,
            _configRegistry
        );

        // Deploy new proxy
        GildiWalletBeaconProxy newProxy = new GildiWalletBeaconProxy(_beacon, initData, _owner, _gildiOperator);

        proxyAddress = address(newProxy);
        _deployedProxies.push(proxyAddress);
        _isProxyDeployed[proxyAddress] = true;

        emit ProxyDeployed(proxyAddress, _owner, _gildiOperator, _externalId);
    }

    /// @notice Returns the number of proxies deployed by this factory
    /// @return The number of deployed proxies
    function getProxyCount() external view returns (uint256) {
        return _deployedProxies.length;
    }

    /// @notice Returns a list of deployed proxies
    /// @param cursor The cursor to start from
    /// @param count The number of proxies to return
    /// @return proxies An array of deployed proxy addresses
    /// @return nextCursor The cursor to use for the next call
    function getProxies(
        uint256 cursor,
        uint256 count
    ) external view returns (address[] memory proxies, uint256 nextCursor) {
        uint256 maxCount = _deployedProxies.length;
        if (cursor >= maxCount) {
            return (new address[](0), 0);
        }

        uint256 endCursor = cursor + count;
        if (endCursor > maxCount) {
            endCursor = maxCount;
        }
        proxies = new address[](endCursor - cursor);
        for (uint256 i = cursor; i < endCursor; i++) {
            proxies[i - cursor] = _deployedProxies[i];
        }

        nextCursor = endCursor;
    }

    /// @notice Checks if a proxy is deployed by this factory at a specific address
    /// @param _proxyAddress The address of the proxy to check
    /// @return True if the proxy is deployed, false otherwise
    function isDeployed(address _proxyAddress) external view returns (bool) {
        return _isProxyDeployed[_proxyAddress];
    }
}
