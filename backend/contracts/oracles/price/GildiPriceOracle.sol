// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '../../interfaces/oracles/price/IGildiPriceOracle.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/// @title Gildi Price Oracle
/// @notice Manages asset pairs and delegates price resolution to resolvers
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiPriceOracle is Initializable, AccessControlUpgradeable, IGildiPriceOracle {
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @dev Mapping from pair hash to IGildiPriceResolver implementation
    mapping(bytes32 => IGildiPriceResolver) private pairResolvers;

    // Custom Errors
    /// @dev Thrown when a non-admin attempts to perform an admin-only action
    error NotAdmin();
    /// @dev Thrown when a resolver address is zero
    error ResolverAddressZero();
    /// @dev Thrown when an index is out of bounds
    error IndexOutOfBounds();
    /// @dev Thrown when an asset is not found
    /// @param assetId The ID of the asset that was not found
    error AssetNotFound(uint256 assetId);
    /// @dev Thrown when a symbol length is invalid
    error InvalidSymbolLength();
    /// @dev Thrown when a pair is not found
    error PairNotFound();
    /// @dev Thrown when a symbol contains invalid characters
    error InvalidSymbol();
    /// @dev Thrown when a symbol is already taken
    error SymbolTaken();

    // Events
    /// @notice Emitted when a resolver is added for a pair
    /// @param baseAsset The base asset address
    /// @param quoteAsset The quote asset address
    /// @param resolver The address of the resolver contract
    event ResolverAdded(string baseAsset, string quoteAsset, address indexed resolver);

    /// @notice Emitted when a pair is deleted
    /// @param pairId The pair ID
    /// @param baseAssetId The base asset id
    /// @param quoteAssetId The quote asset id
    event PairDeleted(bytes32 pairId, uint256 baseAssetId, uint256 quoteAssetId);

    /// @notice Emitted when an asset is deleted
    /// @param assetId The asset ID
    /// @param symbol The asset symbol
    /// @param name The asset name
    event AssetDeleted(uint256 assetId, string symbol, string name);

    // Assets
    /// @dev Array of all pairs
    Pair[] private pairs;
    /// @dev Mapping to track if a pair exists
    mapping(bytes32 => bool) private pairExists;

    /// @dev Map asset ID -> Asset
    mapping(uint256 => Asset) private assetRegistry;
    /// @dev Next asset ID to be assigned
    uint256 private nextAssetId;
    /// @dev Maps uppercase symbol -> assetId
    mapping(bytes32 => uint256) private symbolToId;
    /// @dev Store assets in an array for getAssets()
    Asset[] private allAssets;

    // Pairs
    /// @dev Structure to represent an asset pair
    struct Pair {
        /// @dev The unique identifier for the base asset
        uint256 baseAssetId;
        /// @dev The unique identifier for the quote asset
        uint256 quoteAssetId;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and sets up roles
    /// @param _defaultAdmin The address of the default admin
    /// @param _contractAdmin The address of the contract admin
    function initialize(address _defaultAdmin, address _contractAdmin) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(ADMIN_ROLE, _contractAdmin);
    }

    /// @inheritdoc IGildiPriceOracle
    function getResolver(bytes32 _pairId) external view override returns (IGildiPriceResolver resolver) {
        if (!pairExists[_pairId]) {
            revert InvalidPairId();
        }

        resolver = pairResolvers[_pairId];
        return resolver;
    }

    /// @dev Computes a unique pair ID for an asset pair
    /// @param _baseAsset The base asset address
    /// @param _quoteAsset The quote asset address
    /// @return The hash of the asset pair
    function _generatePairId(string memory _baseAsset, string memory _quoteAsset) internal pure returns (bytes32) {
        // Convert both strings to uppercase, then hash them together
        // (or just hash them directly if preferred)
        bytes memory b1 = bytes(_baseAsset);
        bytes memory b2 = bytes(_quoteAsset);
        for (uint i = 0; i < b1.length; i++) {
            if (b1[i] >= 0x61 && b1[i] <= 0x7A) {
                b1[i] = bytes1(uint8(b1[i]) - 32);
            }
        }
        for (uint j = 0; j < b2.length; j++) {
            if (b2[j] >= 0x61 && b2[j] <= 0x7A) {
                b2[j] = bytes1(uint8(b2[j]) - 32);
            }
        }
        return keccak256(abi.encodePacked(b1, '/', b2));
    }

    /// @notice Return all pairs in the form "BASE/QUOTE" for direct usage
    /// @return An array of PairInfo structs containing all registered pairs
    function getPairs() external view returns (PairInfo[] memory) {
        PairInfo[] memory pairList = new PairInfo[](pairs.length);
        for (uint i = 0; i < pairs.length; i++) {
            Asset memory baseAsset = assetRegistry[pairs[i].baseAssetId];
            Asset memory quoteAsset = assetRegistry[pairs[i].quoteAssetId];

            pairList[i] = PairInfo({
                pairId: _generatePairId(baseAsset.symbol, quoteAsset.symbol),
                baseAsset: baseAsset,
                quoteAsset: quoteAsset
            });
        }
        return pairList;
    }

    /// @notice Adds a new asset to the registry
    /// @param _symbol The symbol of the asset
    /// @param _name The name of the asset
    /// @return The ID of the newly added asset
    function addAsset(string memory _symbol, string memory _name) external onlyRole(ADMIN_ROLE) returns (uint256) {
        // Validate & uppercase symbol
        bytes memory s = bytes(_symbol);
        if (s.length < 3 || s.length > 6) {
            revert InvalidSymbolLength();
        }

        for (uint i = 0; i < s.length; i++) {
            if (s[i] >= 0x61 && s[i] <= 0x7A) {
                s[i] = bytes1(uint8(s[i]) - 32);
            }
            // Only [A-Z0-9] allowed
            if ((s[i] < 0x30 || s[i] > 0x39) && (s[i] < 0x41 || s[i] > 0x5A)) {
                revert InvalidSymbol();
            }
        }
        bytes32 symbolHash = keccak256(s);
        if (symbolToId[symbolHash] != 0) {
            revert SymbolTaken();
        }

        nextAssetId++;
        assetRegistry[nextAssetId] = Asset(nextAssetId, string(s), _name);
        symbolToId[symbolHash] = nextAssetId;
        allAssets.push(assetRegistry[nextAssetId]);
        return nextAssetId;
    }

    /// @notice Deletes an asset and all pairs that reference it
    /// @param _assetId The ID of the asset to delete
    function deleteAsset(uint256 _assetId) external onlyRole(ADMIN_ROLE) {
        // 1. Check that the asset exists
        Asset memory asset = assetRegistry[_assetId];
        if (asset.id != _assetId) {
            revert AssetNotFound(_assetId);
        }

        // 2. Remove the asset from assetRegistry and symbolToId
        delete assetRegistry[_assetId];

        // Convert symbol to uppercase hash (same logic used for pair ID generation)
        bytes memory symbolBytes = bytes(asset.symbol);
        for (uint256 k = 0; k < symbolBytes.length; k++) {
            // uppercase ASCII conversion
            if (symbolBytes[k] >= 0x61 && symbolBytes[k] <= 0x7A) {
                symbolBytes[k] = bytes1(uint8(symbolBytes[k]) - 32);
            }
        }
        bytes32 symbolHash = keccak256(symbolBytes);
        delete symbolToId[symbolHash];

        // Remove from allAssets array
        uint256 length = allAssets.length;
        for (uint256 i = 0; i < length; i++) {
            if (allAssets[i].id == _assetId) {
                allAssets[i] = allAssets[length - 1];
                allAssets.pop();
                break;
            }
        }

        // 3. Remove all pairs referencing this asset
        uint256 pairCount = pairs.length;
        uint256 idx = 0;
        while (idx < pairCount) {
            Pair memory p = pairs[idx];
            if (p.baseAssetId == _assetId || p.quoteAssetId == _assetId) {
                // Compute pairId
                Asset memory baseA = assetRegistry[p.baseAssetId];
                Asset memory quoteA = assetRegistry[p.quoteAssetId];

                // If baseA or quoteA was also deleted, we can still reconstruct the pair ID
                // from the original strings we stored in memory (asset.symbol) if needed.
                // If you strictly need the original uppercase symbols, you can store them
                // temporarily before deleting, but let's keep it straightforward here.
                bytes32 pairId = _generatePairId(baseA.symbol, quoteA.symbol);

                // Delete from pairResolvers and pairExists
                delete pairResolvers[pairId];
                pairExists[pairId] = false;

                // Emit an event
                emit PairDeleted(pairId, baseA.id, quoteA.id);

                // Remove the pair from the array
                pairs[idx] = pairs[pairCount - 1];
                pairs.pop();
                pairCount--;
            } else {
                idx++;
            }
        }

        // 4. Emit asset deleted event
        emit AssetDeleted(_assetId, asset.symbol, asset.name);
    }

    /// @notice Deletes a pair from the oracle
    /// @param _pairId The ID of the pair to delete
    function deletePair(bytes32 _pairId) external onlyRole(ADMIN_ROLE) {
        // 1. Check that the pair exists
        if (!pairExists[_pairId]) {
            revert PairNotFound();
        }

        uint256 baseAssetId = 0;
        uint256 quoteAssetId = 0;

        // 2. Delete the pair from pairResolvers, pairExists and pairs
        delete pairResolvers[_pairId];
        pairExists[_pairId] = false;
        for (uint256 i = 0; i < pairs.length; i++) {
            Asset memory baseAsset = assetRegistry[pairs[i].baseAssetId];
            Asset memory quoteAsset = assetRegistry[pairs[i].quoteAssetId];
            if (_generatePairId(baseAsset.symbol, quoteAsset.symbol) == _pairId) {
                pairs[i] = pairs[pairs.length - 1];
                pairs.pop();

                baseAssetId = baseAsset.id;
                quoteAssetId = quoteAsset.id;
                break;
            }
        }

        // 3. Emit pair deleted event
        emit PairDeleted(_pairId, baseAssetId, quoteAssetId);
    }

    /// @notice Return all registered assets
    /// @return An array of all assets in the registry
    function getAssets() external view returns (Asset[] memory) {
        return allAssets;
    }

    /// @notice Return asset by ID
    /// @param _assetId The ID of the asset to retrieve
    /// @return The asset with the specified ID
    function getAssetById(uint256 _assetId) external view returns (Asset memory) {
        return assetRegistry[_assetId];
    }

    /// @notice Add a new pair using numeric asset IDs
    /// @param _baseAssetId The ID of the base asset
    /// @param _quoteAssetId The ID of the quote asset
    /// @param _resolver The resolver contract for the pair
    function addPair(
        uint256 _baseAssetId,
        uint256 _quoteAssetId,
        IGildiPriceResolver _resolver
    ) external onlyRole(ADMIN_ROLE) {
        // Ensure both assets exist
        if (assetRegistry[_baseAssetId].id == 0) {
            revert AssetNotFound(_baseAssetId);
        }
        if (assetRegistry[_quoteAssetId].id == 0) {
            revert AssetNotFound(_quoteAssetId);
        }

        if (address(_resolver) == address(0)) {
            revert ResolverAddressZero();
        }

        // Convert to uppercase for hashing
        bytes32 pairId = _generatePairId(assetRegistry[_baseAssetId].symbol, assetRegistry[_quoteAssetId].symbol);
        pairResolvers[pairId] = _resolver;

        if (!pairExists[pairId]) {
            pairs.push(Pair(assetRegistry[_baseAssetId].id, assetRegistry[_quoteAssetId].id));
            pairExists[pairId] = true;
        }

        emit ResolverAdded(assetRegistry[_baseAssetId].symbol, assetRegistry[_quoteAssetId].symbol, address(_resolver));
    }

    /// @notice Update the resolver for an existing pair
    /// @param _baseAssetId The ID of the base asset
    /// @param _quoteAssetId The ID of the quote asset
    /// @param _resolver The new resolver contract for the pair
    function updateResolver(
        uint256 _baseAssetId,
        uint256 _quoteAssetId,
        IGildiPriceResolver _resolver
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 pairId = _generatePairId(assetRegistry[_baseAssetId].symbol, assetRegistry[_quoteAssetId].symbol);
        pairResolvers[pairId] = _resolver;
    }

    /// @notice Return pairs that use a specific quote asset ID
    /// @param _quoteAssetId The ID of the quote asset to filter by
    /// @return An array of pair strings in the format "BASE/QUOTE"
    function getPairsByQuoteAsset(uint256 _quoteAssetId) external view returns (string[] memory) {
        if (assetRegistry[_quoteAssetId].id == 0) {
            revert AssetNotFound(_quoteAssetId);
        }
        string memory quoteSymbol = assetRegistry[_quoteAssetId].symbol;

        Asset memory pairQuoteAsset;

        // Filter pairs where pair.quoteAsset == quoteSymbol
        uint count;
        for (uint i = 0; i < pairs.length; i++) {
            pairQuoteAsset = assetRegistry[pairs[i].quoteAssetId];
            if (keccak256(bytes(pairQuoteAsset.symbol)) == keccak256(bytes(quoteSymbol))) {
                count++;
            }
        }

        string[] memory results = new string[](count);
        uint index;
        for (uint j = 0; j < pairs.length; j++) {
            pairQuoteAsset = assetRegistry[pairs[j].quoteAssetId];
            if (keccak256(bytes(pairQuoteAsset.symbol)) == keccak256(bytes(quoteSymbol))) {
                Asset memory pairBaseAsset = assetRegistry[pairs[j].baseAssetId];
                results[index] = string(abi.encodePacked(pairBaseAsset.symbol, '/', pairQuoteAsset.symbol));
                index++;
            }
        }
        return results;
    }

    /// @notice Overload to get price by numeric IDs
    /// @param _baseAssetId The ID of the base asset
    /// @param _quoteAssetId The ID of the quote asset
    /// @return Price data for the specified asset pair
    function getPriceById(uint256 _baseAssetId, uint256 _quoteAssetId) external view returns (PriceData memory) {
        if (assetRegistry[_baseAssetId].id == 0) {
            revert AssetNotFound(_baseAssetId);
        }
        if (assetRegistry[_quoteAssetId].id == 0) {
            revert AssetNotFound(_quoteAssetId);
        }

        bytes32 pairId = _generatePairId(assetRegistry[_baseAssetId].symbol, assetRegistry[_quoteAssetId].symbol);
        IGildiPriceResolver resolver = pairResolvers[pairId];
        if (!pairExists[pairId]) {
            revert InvalidPairId();
        }

        return resolver.getPrice(pairId);
    }

    /// @inheritdoc IGildiPriceResolver
    function getPrice(bytes32 _pairId) external view override returns (PriceData memory) {
        IGildiPriceResolver resolver = pairResolvers[_pairId];
        if (!pairExists[_pairId]) {
            revert InvalidPairId();
        }

        return resolver.getPrice(_pairId);
    }

    /// @inheritdoc IGildiPriceResolver
    function getPriceNoOlderThan(bytes32 _pairId, uint256 _age) external view override returns (PriceData memory) {
        IGildiPriceResolver resolver = pairResolvers[_pairId];
        if (!pairExists[_pairId]) {
            revert InvalidPairId();
        }

        return resolver.getPriceNoOlderThan(_pairId, _age);
    }

    /// @inheritdoc IGildiPriceOracle
    function pairExistsById(bytes32 _pairId) external view override returns (bool) {
        return pairExists[_pairId];
    }
}
