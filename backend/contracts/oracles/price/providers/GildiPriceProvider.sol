// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '../../../interfaces/oracles/price/IGildiPriceResolver.sol';
import '../../../interfaces/oracles/price/IGildiPriceOracle.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/// @title Gildi Price Provider
/// @notice Provides price data for asset pairs
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiPriceProvider is Initializable, IGildiPriceResolver, AccessControlUpgradeable {
    bytes32 public constant PRICE_FEEDER_ROLE = keccak256('PRICE_FEEDER_ROLE');
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @dev Mapping from pairId => PriceData
    mapping(bytes32 => PriceData) private prices;
    /// @dev Array of all pair IDs with price data
    bytes32[] private pairIds;
    /// @dev Reference to the Gildi price oracle contract
    IGildiPriceOracle private oracle;

    // Structs
    struct PriceUpdate {
        bytes32 pairId;
        uint256 price;
        uint8 decimals;
    }

    // Custom Errors
    /// @dev Thrown when a non-price feeder attempts to set price data
    error NotPriceFeeder();
    /// @dev Thrown when an invalid price (zero) is provided
    error InvalidPrice();
    /// @dev Thrown when price data is not available for a requested pair
    error PriceDataNotAvailable();
    /// @dev Thrown when a pair is not found
    error PairNotFound();
    /// @dev Thrown when a price is older than the requested maximum age
    error StalePrice();

    // Events
    /// @notice Emitted when a price is updated
    /// @param pairId The pair ID
    /// @param price The updated price
    /// @param decimals The number of decimals for the price
    /// @param timestamp The timestamp when the price was updated
    event PriceUpdated(bytes32 indexed pairId, uint256 price, uint8 decimals, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and sets up roles
    /// @param _defaultAdmin The address of the default admin
    /// @param _contractAdmin The address of the contract admin
    /// @param _oracle The address of the Gildi price oracle
    function initialize(address _defaultAdmin, address _contractAdmin, IGildiPriceOracle _oracle) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(ADMIN_ROLE, _contractAdmin);
        oracle = _oracle;
    }

    /// @notice Sets the price data for a given pair
    /// @param _priceUpdate The price data to set
    function setPriceData(PriceUpdate calldata _priceUpdate) external onlyRole(PRICE_FEEDER_ROLE) {
        _setPriceData(_priceUpdate);
    }

    /// @notice Sets the price data for multiple pairs in a single transaction
    /// @param _priceUpdates Array of price updates
    function setPriceData(PriceUpdate[] calldata _priceUpdates) external onlyRole(PRICE_FEEDER_ROLE) {
        for (uint256 i = 0; i < _priceUpdates.length; i++) {
            _setPriceData(_priceUpdates[i]);
        }
    }

    /// @notice Deletes the price data for a given pair
    /// @param _pairId The pair ID
    function deletePriceDataForPair(bytes32 _pairId) external onlyRole(ADMIN_ROLE) {
        if (prices[_pairId].timestamp == 0) {
            revert PairNotFound();
        }

        delete prices[_pairId];
        for (uint256 i = 0; i < pairIds.length; i++) {
            if (pairIds[i] == _pairId) {
                pairIds[i] = pairIds[pairIds.length - 1];
                pairIds.pop();
                break;
            }
        }
    }

    /// @inheritdoc IGildiPriceResolver
    function getPrice(bytes32 _pairId) external view override returns (PriceData memory priceData) {
        if (prices[_pairId].timestamp == 0) {
            revert PriceDataNotAvailable();
        }
        return prices[_pairId];
    }

    /// @inheritdoc IGildiPriceResolver
    function getPriceNoOlderThan(
        bytes32 _pairId,
        uint256 _age
    ) external view override returns (PriceData memory priceData) {
        if (prices[_pairId].timestamp == 0) {
            revert PriceDataNotAvailable();
        }
        if (block.timestamp - prices[_pairId].timestamp > _age) {
            revert StalePrice();
        }
        return prices[_pairId];
    }

    /// @notice Retrieves all pairs with price data
    /// @return pairInfos An array of PairInfo structs
    function getPairs() external view returns (IGildiPriceOracle.PairInfo[] memory) {
        IGildiPriceOracle.PairInfo[] memory pairInfos = new IGildiPriceOracle.PairInfo[](pairIds.length);
        IGildiPriceOracle.PairInfo[] memory allOraclePairs = oracle.getPairs();
        for (uint256 i = 0; i < pairIds.length; i++) {
            for (uint256 j = 0; j < allOraclePairs.length; j++) {
                if (allOraclePairs[j].pairId == pairIds[i]) {
                    pairInfos[i] = allOraclePairs[j];
                    break;
                }
            }

            if (pairInfos[i].pairId == 0) {
                pairInfos[i] = IGildiPriceOracle.PairInfo(
                    pairIds[i],
                    IGildiPriceOracle.Asset(0, 'UNKNOWN', 'UNKNOWN'),
                    IGildiPriceOracle.Asset(0, 'UNKNOWN', 'UNKNOWN')
                );
            }
        }

        return pairInfos;
    }

    /// @dev Internal function to set price data for a given pair
    /// @param _priceUpdate The price data to set
    function _setPriceData(PriceUpdate calldata _priceUpdate) internal {
        if (_priceUpdate.price == 0) {
            revert InvalidPrice();
        }
        if (!oracle.pairExistsById(_priceUpdate.pairId)) {
            revert IGildiPriceOracle.InvalidPairId();
        }

        if (prices[_priceUpdate.pairId].timestamp == 0) {
            pairIds.push(_priceUpdate.pairId);
        }

        prices[_priceUpdate.pairId] = PriceData(_priceUpdate.price, _priceUpdate.decimals, block.timestamp);
        emit PriceUpdated(_priceUpdate.pairId, _priceUpdate.price, _priceUpdate.decimals, block.timestamp);
    }
}
