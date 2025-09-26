// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import {SharedErrors} from '../../libraries/marketplace/exchange/SharedErrors.sol';
import {IERC20Burnable} from '../../interfaces/token/IERC20Burnable.sol';
import {IGildiPriceResolver} from '../../interfaces/oracles/price/IGildiPriceOracle.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/// @title Gildi Exchange
/// @notice Marketplace of the Gildi platform.
/// @custom:security-contact security@gildi.to
/// @author Gildi Digital LLC
contract GildiExchange is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IGildiExchange
{
    using SafeERC20 for IERC20;

    // ========== Constants ==========
    /// @notice Role identifier for admin access
    bytes32 private constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @notice Role identifier for marketplace manager access
    bytes32 private constant MARKETPLACE_MANAGER_ROLE = keccak256('MARKETPLACE_MANAGER_ROLE');

    /// @notice Role identifier for fund claimer access
    bytes32 private constant CLAIMER_ROLE = keccak256('CLAIMER_ROLE');

    /// @notice Basis points denominator for percentage calculations (100% = 10000)
    uint16 private constant BASIS_POINTS = 10000;

    /// @notice Default slippage tolerance in basis points (1%)
    uint16 public constant DEFAULT_SLIPPAGE_BPS = 100;

    // ========== Storage Variables ==========
    /// @notice Application settings for the exchange
    AppSettings private appSettings;

    /// @notice Array of all release IDs in the exchange
    uint256[] private releaseIds;
    /// @notice Mapping from release ID to Release struct
    mapping(uint256 => Release) public releases;

    /// @notice Mapping from release ID to InitialSale struct
    mapping(uint256 => InitialSale) private initialSales;
    /// @notice Mapping from release ID to array of whitelist buyer addresses
    mapping(uint256 => address[]) private initialSaleWhitelistBuyers;
    /// @notice Mapping from release ID to buyer address to whitelist status
    mapping(uint256 => mapping(address => bool)) public isInitialSaleWhitelistBuyer;
    /// @notice Mapping from release ID to buyer address to maximum buy count
    mapping(uint256 => mapping(address => uint256)) private initialSaleMaxBuyCounts;
    /// @notice Mapping from release ID to total quantity listed in initial sale
    mapping(uint256 => uint256) private initialSaleListedQuantities;

    // ========== Structs ==========

    /// @notice Parameters for creating an initial sale
    struct InitialSaleParams {
        /// @dev The ID of the release
        uint256 releaseId;
        /// @dev The quantities of the asset
        uint256[] assetQuantities;
        /// @dev The prices of the asset for the quantity bracket
        uint256[] assetPrices;
        /// @dev The address of the seller (owner of the shares)
        address seller;
        /// @dev The maximum amount of tokens a buyer can buy in the initial sale
        uint256 maxBuy;
        /// @dev The start time of the initial sale
        uint256 start;
        /// @dev The duration of the initial sale (default 1 week)
        uint256 duration;
        /// @dev If the initial sale is a whitelist sale
        bool whitelist;
        /// @dev The addresses of the whitelist
        address[] whitelistAddresses;
        /// @dev The duration the whitelist is enforced (default 0 = forever)
        uint256 whitelistDuration;
        /// @dev Overrides the marketplace currency for the initial sale
        address initialSaleCurrency;
        /// @dev The currency to pay out in
        address payoutCurrency;
        /// @dev The address to receive funds from the sale (if address(0), defaults to seller)
        address fundsReceiver;
        /// @dev The fee distribution structure for the initial sale
        FeeDistribution[] fees;
    }

    /// @notice A marketplace release
    struct Release {
        /// @dev The ID of the release
        uint256 releaseId;
        /// @dev Additional fees for this release
        FeeDistribution[] additionalFees;
        /// @dev If the release is initialized (set)
        bool initialized;
        /// @dev If the release is active = can be traded
        bool active;
        /// @dev If the release is in the process of being cancelled
        bool isCancelling;
    }

    /// @notice Initial sale related data
    struct InitialSale {
        /// @dev If the release is in initial sale state
        bool active;
        /// @dev If the initial sale is a whitelist sale
        bool whitelist;
        /// @dev When the initial sale starts
        uint256 startTime;
        /// @dev When the initial sale ends
        uint256 endTime;
        /// @dev Until when the whitelist is enforced (0 = unlimited)
        uint256 whitelistUntil;
        /// @dev Maximum amount of tokens a buyer can buy in the initial sale
        uint256 maxBuy;
        /// @dev The sale currency of the initial sale
        address saleCurrency;
        /// @dev The fee distribution structure for the initial sale
        FeeDistribution[] fees;
    }

    // ========== Events ==========

    /// @notice Emitted when a purchase is made
    /// @param releaseId The ID of the release being purchased
    /// @param buyer The address of the buyer
    /// @param seller The address of the seller
    /// @param operator The address of the operator
    /// @param listingId The ID of the listing
    /// @param priceInUSD The price per item in USD
    /// @param quantity The quantity of the release being purchased
    event Purchased(
        uint256 indexed releaseId,
        address indexed buyer,
        address indexed seller,
        address operator,
        uint256 listingId,
        uint256 priceInUSD,
        uint256 quantity,
        uint256 priceInAsset,
        address asset
    );

    /// @notice Emitted when a release cancellation is started
    /// @param releaseId The ID of the release being cancelled
    event ReleaseCancellationStarted(uint256 indexed releaseId);

    /// @notice Emitted when a release is fully cancelled
    /// @param releaseId The ID of the release being cancelled
    event ReleaseCancelled(uint256 indexed releaseId);

    /// @notice Emitted when an initial sale is created
    /// @param releaseId The ID of the release
    /// @param seller The address of the seller
    /// @param assetQuantities The quantities of the asset
    /// @param assetPrices The prices of the asset for the quantity bracket
    /// @param maxBuy The maximum amount of tokens a buyer can buy in the initial sale
    /// @param startTime The start time of the initial sale
    /// @param duration The duration of the initial sale
    /// @param whitelistEnabled If the initial sale is a whitelist sale
    /// @param whitelistDuration The duration the whitelist is enforced
    /// @param saleCurrency The currency of the initial sale
    /// @param payoutCurrency The currency of the payout
    /// @param saleFees The fees for the initial sale
    event InitialSaleCreated(
        uint256 indexed releaseId,
        address indexed seller,
        uint256[] assetQuantities,
        uint256[] assetPrices,
        uint256 maxBuy,
        uint256 startTime,
        uint256 duration,
        bool whitelistEnabled,
        uint256 whitelistDuration,
        address saleCurrency,
        address payoutCurrency,
        FeeDistribution[] saleFees
    );

    /// @notice Emitted when the initial sale ends
    /// @param releaseId The ID of the release
    event InitialSaleEnded(uint256 indexed releaseId);

    /// @notice Emitted when a release is initialized
    /// @param releaseId The ID of the release
    event ReleaseInitialized(uint256 indexed releaseId);

    /// @notice Emitted when a release's active state is changed
    /// @param releaseId The ID of the release
    /// @param isActive The new active state
    event ReleaseActiveStateChanged(uint256 indexed releaseId, bool isActive);

    /// @notice Emitted when a release's fees are updated
    /// @param releaseId The ID of the release
    event FeesUpdated(uint256 indexed releaseId);

    /// @notice Emitted when the ask decimals are set
    /// @param askDecimals The new ask decimals
    event AskDecimalsSet(uint8 askDecimals);

    /// @notice Emitted when the marketplace currency is set
    /// @param marketplaceCurrency The new marketplace currency
    event MarketplaceCurrencySet(address marketplaceCurrency);

    // ========== Errors ==========

    /// @dev Emitted when the requested quantity exceeds available inventory.
    /// @dev The quantity that was requested.
    /// @dev The quantity that was available.
    error InsufficientQuantity(uint256 requested, uint256 available);

    /// @dev Emitted when a purchase cannot proceed (e.g. buyer not whitelisted, amount exceeds max buy, not enough tokens).
    error PurchaseError();

    /// @dev Emitted when there is a setup/configuration issue (e.g. oracle decimals not set, invalid fee distribution).
    error SetupError();

    /// @dev Emitted when a release is not found in the manager (e.g. gildiManager.releaseExists(...) fails).
    /// @dev The ID that could not be found.
    error ReleaseNotFound(uint256 releaseId);

    /// @dev Emitted when the requested number of tokens to buy cannot be fulfilled by the available listings.
    /// @dev The total amount of tokens requested
    /// @dev The amount of tokens actually found in listings
    error NotEnoughTokensInListings(uint256 requested, uint256 available);

    /// @dev Emitted when a release is in a wrong state (e.g. uninitialized, cancelling when it should not be, or active/inactive mismatch).
    /// @dev The ID of the release in question.
    error ReleaseStateError(uint256 releaseId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Constructor and Initializer ==========

    /// @notice Initializes the contract
    /// @param _initialDefaultAdmin The address of the initial default admin
    /// @param _initialAdmin The address of the initial admin
    /// @param _initialMarketplaceManager The address of the initial marketplace manager
    /// @param _gildiManager The address of the Gildi Manager
    /// @param _marketplaceCurrency The address of the marketplace currency
    function initialize(
        address _initialDefaultAdmin,
        address _initialAdmin,
        address _initialMarketplaceManager,
        IGildiManager _gildiManager,
        IERC20 _marketplaceCurrency
    ) public initializer {
        AppSettings storage $ = appSettings;

        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        if (_initialDefaultAdmin == address(0)) {
            _initialDefaultAdmin = _msgSender();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, _initialDefaultAdmin);

        if (_initialAdmin != address(0)) {
            _grantRole(ADMIN_ROLE, _initialAdmin);
        }

        if (_initialMarketplaceManager != address(0)) {
            _grantRole(MARKETPLACE_MANAGER_ROLE, _initialMarketplaceManager);
        }

        $.maxBuyPerTransaction = 15;

        $.gildiManager = _gildiManager;
        _setMarketplaceCurrency(address(_marketplaceCurrency));
    }

    // ========== Main Marketplace Logic ==========

    /// @notice Creates an initial sale.
    /// @param _params The parameters for creating the initial sale
    function createInitialSale(
        InitialSaleParams calldata _params
    ) external whenNotPaused onlyRole(MARKETPLACE_MANAGER_ROLE) {
        AppSettings storage $ = appSettings;

        // Validate release state - combine multiple checks
        Release storage release = releases[_params.releaseId];
        if (
            !release.initialized ||
            release.active ||
            release.isCancelling ||
            !$.gildiManager.isLocked(_params.releaseId) ||
            $.gildiManager.isInInitialSale(_params.releaseId) ||
            isInInitialSale(_params.releaseId)
        ) {
            revert ReleaseStateError(_params.releaseId);
        }

        // Validate function parameters
        if (
            _params.assetQuantities.length != _params.assetPrices.length ||
            (_params.whitelist && _params.whitelistAddresses.length == 0) ||
            (!_params.whitelist && _params.whitelistAddresses.length > 0)
        ) {
            revert SharedErrors.ParamError();
        }

        // Check if we have a feed for the initial sale currency
        if (
            _params.initialSaleCurrency != address(0) &&
            $.paymentProcessor.getPriceFeedId(_params.initialSaleCurrency) == bytes32(0)
        ) {
            revert SharedErrors.ParamError();
        }

        // Adjust start time and duration if needed
        uint256 startTime = _params.start < block.timestamp ? block.timestamp : _params.start;
        uint256 duration = _params.duration == 0 ? 1 weeks : _params.duration;

        // Calculate whitelist end time
        uint256 whitelistUntil = (_params.whitelist && _params.whitelistDuration != 0)
            ? startTime + _params.whitelistDuration
            : 0;

        // Setup initial sale
        InitialSale storage initialSale = initialSales[_params.releaseId];
        initialSale.whitelist = _params.whitelist;
        initialSale.whitelistUntil = whitelistUntil;
        initialSale.maxBuy = _params.maxBuy;
        initialSale.saleCurrency = _params.initialSaleCurrency;

        _enforceValidFeeDistribution(_params.fees);
        initialSale.fees = _params.fees;

        // Process whitelist addresses in a single loop
        uint256 whitelistLength = _params.whitelistAddresses.length;
        for (uint256 i = 0; i < whitelistLength; i++) {
            address buyer = _params.whitelistAddresses[i];
            if (!isInitialSaleWhitelistBuyer[_params.releaseId][buyer]) {
                isInitialSaleWhitelistBuyer[_params.releaseId][buyer] = true;
                initialSaleWhitelistBuyers[_params.releaseId].push(buyer);
            }
        }

        release.active = true;
        initialSale.active = true;
        initialSale.startTime = startTime;
        initialSale.endTime = startTime + duration;

        $.gildiManager.startInitialSale(_params.releaseId);

        for (uint256 i = 0; i < _params.assetQuantities.length; i++) {
            initialSaleListedQuantities[_params.releaseId] += _params.assetQuantities[i];

            // Use the orderBook to create the listing
            $.orderBook.handleCreateListing(
                _params.releaseId,
                _params.seller,
                _params.assetPrices[i],
                _params.assetQuantities[i],
                _params.payoutCurrency,
                _params.fundsReceiver,
                DEFAULT_SLIPPAGE_BPS
            );
        }

        emit InitialSaleCreated(
            _params.releaseId,
            _params.seller,
            _params.assetQuantities,
            _params.assetPrices,
            _params.maxBuy,
            _params.start,
            _params.duration,
            _params.whitelist,
            _params.whitelistDuration,
            _params.initialSaleCurrency,
            _params.payoutCurrency,
            _params.fees
        );
    }

    /// @notice Cancels a release in batches.
    /// @param _releaseId The ID of the release
    /// @param _batchSize The batch size (min 1, max 100)
    function cancelRelease(uint256 _releaseId, uint256 _batchSize) external onlyRole(MARKETPLACE_MANAGER_ROLE) {
        AppSettings storage $ = appSettings;

        if (_batchSize > 100 || _batchSize == 0) {
            revert SharedErrors.ParamError();
        }

        Release storage release = releases[_releaseId];
        InitialSale storage initialSale = initialSales[_releaseId];

        if (!release.initialized) {
            revert ReleaseStateError(_releaseId);
        }

        if (release.active) {
            revert ReleaseStateError(_releaseId);
        }

        if (!release.isCancelling) {
            release.isCancelling = true;
            emit ReleaseCancellationStarted(_releaseId);
        }

        if (initialSale.active) {
            $.gildiManager.cancelInitialSale(_releaseId);
        }

        uint256 i = 0;

        // Process batch of listings
        uint256 batchToProcess = _batchSize > 100 ? 100 : _batchSize;

        try $.orderBook.handleUnlistReleaseListings(_releaseId, batchToProcess) returns (uint256 processedCount) {
            i += processedCount;
        } catch {}
        // Process funds using the fund manager
        uint256 fundsProcessed = 0;
        if (i < _batchSize) {
            try $.fundManager.handleCancelReleaseFunds(_releaseId, _batchSize - i) returns (uint256 processedCount) {
                fundsProcessed = processedCount;
                i += fundsProcessed;
            } catch {}
        } else {
            return;
        }

        if ($.orderBook.listedQuantities(_releaseId) == 0 && !$.fundManager.releaseHasFunds(_releaseId)) {
            // Clean up initial sale mappings in batch constraints
            if (initialSale.active) {
                for (; i < initialSaleWhitelistBuyers[_releaseId].length && i < _batchSize; i++) {
                    address buyer = initialSaleWhitelistBuyers[_releaseId][i];
                    delete isInitialSaleWhitelistBuyer[_releaseId][buyer];
                    delete initialSaleMaxBuyCounts[_releaseId][buyer];
                }
                if (initialSaleWhitelistBuyers[_releaseId].length > 0) {
                    return;
                }

                delete initialSaleWhitelistBuyers[_releaseId];
                delete initialSaleListedQuantities[_releaseId];
            }

            delete releases[_releaseId];
            delete initialSales[_releaseId];

            for (uint256 j = 0; j < releaseIds.length; j++) {
                if (releaseIds[j] == _releaseId) {
                    releaseIds[j] = releaseIds[releaseIds.length - 1];
                    releaseIds.pop();
                    break;
                }
            }
            emit ReleaseCancelled(_releaseId);
        }
    }

    /// @inheritdoc IGildiExchange
    function createListing(
        uint256 _releaseId,
        address _seller,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external whenNotPaused {
        _createListing(
            _releaseId,
            _seller,
            _pricePerItem,
            _quantity,
            _payoutCurrency,
            _fundsReceiver,
            DEFAULT_SLIPPAGE_BPS
        );
    }

    /// @inheritdoc IGildiExchange
    function modifyListing(
        uint256 _listingId,
        uint256 _newPricePerItem,
        uint256 _newQuantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external whenNotPaused {
        _modifyListing(
            _listingId,
            _newPricePerItem,
            _newQuantity,
            _payoutCurrency,
            _fundsReceiver,
            DEFAULT_SLIPPAGE_BPS
        );
    }

    /// @notice Cancels a listing by ID
    /// @param _listingId The ID of the listing
    function cancelListing(uint256 _listingId) external nonReentrant whenNotPaused {
        AppSettings storage $ = appSettings;

        // Get the listing from the order book
        IGildiExchangeOrderBook.Listing memory listing = $.orderBook.getListing(_listingId);

        // Only the listing owner or someone with ADMIN_ROLE can cancel a listing
        if (listing.seller != _msgSender() && !hasRole(ADMIN_ROLE, _msgSender())) {
            revert SharedErrors.NotAllowed();
        }

        if ($.gildiManager.isInInitialSale(listing.releaseId) && isInInitialSale(listing.releaseId)) {
            revert ReleaseStateError(listing.releaseId);
        }

        // Delegate to the order book to remove the listing
        $.orderBook.handleRemoveListing(_listingId);
    }

    /// @notice Unlists all listings of a release in batches.
    /// @param _releaseId The ID of the release (0 = all)
    /// @param _batchSize The batch size (0 = unlimited)
    function unlistAllListings(uint256 _releaseId, uint256 _batchSize) external onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;

        if (_batchSize == 0) {
            _batchSize = type(uint256).max;
        }

        uint256 totalProcessed = 0;

        // For each release
        for (uint256 i = 0; i < releaseIds.length && totalProcessed < _batchSize; i++) {
            uint256 releaseId = releaseIds[i];

            if (releaseId != _releaseId && _releaseId != 0) {
                continue;
            }

            uint256 remaining = _batchSize - totalProcessed;
            uint256 batchToProcess = remaining > 100 ? 100 : remaining; // Process in chunks of max 100

            // Delegate to the order book
            uint256 processed = $.orderBook.handleUnlistReleaseListings(releaseId, batchToProcess);

            totalProcessed += processed;

            // If we processed less than the batch size, we're done with this release
            if (processed < batchToProcess) {
                break;
            }
        }
    }

    /// @inheritdoc IGildiExchange
    function purchase(
        uint256 _releaseId,
        uint256 _amount,
        uint256 _maxTotalPrice,
        address _beneficiary,
        bool _isProxyOperation
    ) external override nonReentrant whenNotPaused returns (uint256 amountSpent, uint256 amountUsdSpent) {
        address beneficiary = _beneficiary == address(0) ? _msgSender() : _beneficiary;
        (bool buyAllowed, uint256 maxBuy) = canBuy(_releaseId, beneficiary);
        if (!buyAllowed) {
            revert PurchaseError();
        }

        if (maxBuy != 0 && _amount > maxBuy) {
            revert PurchaseError();
        }

        // Default to non-proxy operation when called directly
        (amountSpent, amountUsdSpent) = _performPurchase(
            _releaseId,
            _msgSender(),
            _maxTotalPrice,
            _amount,
            beneficiary,
            _isProxyOperation
        );
    }

    // ========== Admin Functions ==========

    /// @notice Sets the max buy per transaction
    /// @param _maxBuyPerTransaction The maximum buy per transaction (0 = unlimited)
    function setMaxBuyPerTransaction(uint256 _maxBuyPerTransaction) external onlyRole(ADMIN_ROLE) {
        appSettings.maxBuyPerTransaction = _maxBuyPerTransaction;
    }

    /// @notice Pauses the contract
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Initializes the release
    /// @param _tokenId The ID of the release
    /// @param _additionalFees Additional fees for the release
    function initializeRelease(
        uint256 _tokenId,
        FeeDistribution[] calldata _additionalFees
    ) external onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;
        if (releases[_tokenId].initialized) {
            revert ReleaseStateError(_tokenId);
        }

        if (!$.gildiManager.releaseExists(_tokenId)) {
            revert ReleaseNotFound(_tokenId);
        }

        FeeDistribution[] memory feesToCheck = new FeeDistribution[]($.fees.length + _additionalFees.length);
        uint256 toCheckIndex = 0;

        for (uint256 i = 0; i < $.fees.length; i++) {
            feesToCheck[toCheckIndex] = $.fees[i];
            toCheckIndex++;
        }

        for (uint256 i = 0; i < _additionalFees.length; i++) {
            feesToCheck[toCheckIndex] = _additionalFees[i];
            toCheckIndex++;
        }

        _enforceValidFeeDistribution(feesToCheck);

        releases[_tokenId] = Release({
            releaseId: _tokenId,
            initialized: true,
            additionalFees: _additionalFees,
            active: false,
            isCancelling: false
        });

        releaseIds.push(_tokenId);

        emit ReleaseInitialized(_tokenId);
    }

    /// @notice Sets the active state of a release
    /// @param _releaseId The ID of the release
    /// @param _active The active state
    function setReleaseActive(uint256 _releaseId, bool _active) external onlyRole(ADMIN_ROLE) {
        Release storage release = releases[_releaseId];

        if (!release.initialized) {
            revert ReleaseStateError(_releaseId);
        }

        if (_active && release.isCancelling) {
            revert ReleaseStateError(_releaseId);
        }

        release.active = _active;

        emit ReleaseActiveStateChanged(_releaseId, _active);
    }

    /// @notice Sets the fees for a specific release
    /// @param _releaseId The ID of the release
    /// @param _additionalFees The additional fees for the release
    function setReleaseFees(
        uint256 _releaseId,
        FeeDistribution[] calldata _additionalFees
    ) external onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;
        Release storage release = releases[_releaseId];

        if (!release.initialized) {
            revert ReleaseStateError(_releaseId);
        }

        FeeDistribution[] memory feesToCheck = new FeeDistribution[]($.fees.length + _additionalFees.length);
        uint256 toCheckIndex = 0;

        for (uint256 i = 0; i < $.fees.length; i++) {
            feesToCheck[toCheckIndex] = $.fees[i];
            toCheckIndex++;
        }

        for (uint256 i = 0; i < _additionalFees.length; i++) {
            feesToCheck[toCheckIndex] = _additionalFees[i];
            toCheckIndex++;
        }

        _enforceValidFeeDistribution(feesToCheck);
        release.additionalFees = _additionalFees;

        emit FeesUpdated(_releaseId);
    }

    /// @notice Sets the marketplace fees
    function setFees(FeeDistribution[] calldata _fees) external onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;

        _enforceValidFeeDistribution(_fees);
        $.fees = _fees;

        emit FeesUpdated(0);
    }

    /// @notice Sets the number of decimals for price asks
    /// @param _askDecimals The number of decimals for price asks (max 8)
    function setAskDecimals(uint8 _askDecimals) public onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;
        if (_askDecimals == $.priceAskDecimals) {
            return;
        }

        if (_askDecimals > 8) {
            revert SharedErrors.ParamError();
        }

        // If the decimals changed, we need to make sure there are no listings, if there are, throw error
        for (uint256 i = 0; i < releaseIds.length; i++) {
            uint256 releaseId = releaseIds[i];
            // Check if there are any listings for this release using the OrderBook
            if ($.orderBook.listedQuantities(releaseId) > 0) {
                revert SetupError();
            }
        }

        $.priceAskDecimals = _askDecimals;
        emit AskDecimalsSet(_askDecimals);
    }

    /// @notice Sets the marketplace currency
    /// @param _marketplaceCurrency The address of the marketplace currency
    function setMarketplaceCurrency(address _marketplaceCurrency) public onlyRole(ADMIN_ROLE) {
        _setMarketplaceCurrency(_marketplaceCurrency);
    }

    /// @inheritdoc IGildiExchange
    function transferTokenInContext(
        address _from,
        address _to,
        uint256 _value,
        address _amountCurrency
    ) external override {
        AppSettings storage $ = appSettings;

        if (_amountCurrency == address(0) || _from == address(0) || _to == address(0)) {
            revert SharedErrors.ParamError();
        }

        // Make sure caller is payment processor or fund manager
        if (_msgSender() != address($.paymentProcessor) && _msgSender() != address($.fundManager)) {
            revert SharedErrors.InvalidCaller();
        }

        if (_from == _to || _value == 0) {
            return;
        }

        IERC20 token = IERC20(_amountCurrency);
        if (_from == address(this)) {
            token.safeTransfer(_to, _value);
        } else {
            token.safeTransferFrom(_from, _to, _value);
        }
    }

    /// @inheritdoc IGildiExchange
    function tryBurnTokenInContext(
        address _from,
        uint256 _value,
        address _amountCurrency
    ) external override returns (bool) {
        AppSettings storage $ = appSettings;

        if (_amountCurrency == address(0) || _from == address(0)) {
            revert SharedErrors.ParamError();
        }

        // Make sure caller is payment processor
        if (_msgSender() != address($.paymentProcessor)) {
            revert SharedErrors.InvalidCaller();
        }

        IERC20Burnable burnable = IERC20Burnable(_amountCurrency);

        // Try to burn based on source of funds
        try burnable.burnFrom(_from, _value) {
            return true;
        } catch {}
        return false;
    }

    /// @notice Sets up the exchange with required dependencies
    /// @param _gildiPriceOracle The price oracle for currency conversions
    /// @param _askDecimals The number of decimals for price asks
    /// @param _orderBook The order book contract for managing listings
    /// @param _fundManager The fund manager contract for handling funds
    /// @param _paymentAggregator The payment aggregator for handling payments
    function setup(
        IGildiPriceOracle _gildiPriceOracle,
        uint8 _askDecimals,
        IGildiExchangeOrderBook _orderBook,
        IGildiExchangeFundManager _fundManager,
        IGildiExchangePaymentProcessor _paymentProcessor,
        IGildiExchangePaymentAggregator _paymentAggregator
    ) external onlyRole(ADMIN_ROLE) {
        AppSettings storage $ = appSettings;
        setAskDecimals(_askDecimals);

        if (
            address(_gildiPriceOracle) == address(0) ||
            address(_orderBook) == address(0) ||
            address(_fundManager) == address(0) ||
            address(_paymentAggregator) == address(0) ||
            address(_paymentProcessor) == address(0)
        ) {
            revert SharedErrors.ParamError();
        }

        $.gildiPriceOracle = _gildiPriceOracle;
        $.orderBook = _orderBook;
        $.fundManager = _fundManager;
        $.paymentProcessor = _paymentProcessor;
        $.paymentAggregator = _paymentAggregator;
    }

    // ========== View Functions ==========

    /// @notice Gets the whitelist of a release.
    /// @param _releaseId The ID of the release
    /// @return whitelist The whitelist of the release
    function getWhitelist(uint256 _releaseId) external view returns (address[] memory) {
        return initialSaleWhitelistBuyers[_releaseId];
    }

    /// @inheritdoc IGildiExchange
    function quotePricePreview(
        uint256 _releaseId,
        uint256 _amountToBuy,
        address _buyer
    ) external view override returns (uint256, address, uint256) {
        AppSettings storage $ = appSettings;
        Release storage release = releases[_releaseId];

        // Combine multiple state checks into a single condition
        if ((initialSales[_releaseId].active && !release.initialized) || release.isCancelling || !release.active) {
            revert ReleaseStateError(_releaseId);
        }

        // Get the preview information from the OrderBook
        IGildiExchangeOrderBook.PurchasePreview memory preview = $.orderBook.previewPurchase(
            _releaseId,
            _buyer,
            _amountToBuy
        );

        // Check if there are enough tokens available
        if (preview.totalQuantityAvailable < _amountToBuy) {
            revert InsufficientQuantity(_amountToBuy, preview.totalQuantityAvailable);
        }

        // Use USD price from OrderBook's extended PurchasePreview
        return (preview.totalPriceInCurrency, preview.currency, preview.totalPriceUsd);
    }

    /// @inheritdoc IGildiExchange
    function getReleaseFees(uint256 _releaseId) public view override returns (FeeDistribution[] memory) {
        AppSettings storage $ = appSettings;
        Release storage release = releases[_releaseId];

        // If initial sale is active, return initial sale fees
        if (initialSales[_releaseId].active) {
            return initialSales[_releaseId].fees;
        }

        // If no additional fees, just return global fees
        if (release.additionalFees.length == 0) {
            return $.fees;
        }

        uint256 globalLength = $.fees.length;
        uint256 additionalLength = release.additionalFees.length;
        FeeDistribution[] memory combinedFees = new FeeDistribution[](globalLength + additionalLength);

        // Copy global fees first
        for (uint256 i = 0; i < globalLength; i++) {
            combinedFees[i] = $.fees[i];
        }

        // Copy additional fees at offset
        for (uint256 i = 0; i < additionalLength; i++) {
            combinedFees[globalLength + i] = release.additionalFees[i];
        }

        return combinedFees;
    }

    /// @inheritdoc IGildiExchange
    function isInInitialSale(uint256 _releaseId) public view override returns (bool) {
        InitialSale storage initialSale = initialSales[_releaseId];
        return
            initialSale.active && block.timestamp < initialSale.endTime && initialSaleListedQuantities[_releaseId] > 0;
    }

    /// @notice Whether or not the release is in a whitelist sale state
    /// @param _releaseId The ID of the release
    function isWhitelistSale(uint256 _releaseId) public view returns (bool) {
        // First check if it's in initial sale at all
        if (!isInInitialSale(_releaseId)) {
            return false;
        }

        // Check whitelist settings
        InitialSale storage initialSale = initialSales[_releaseId];
        if (!initialSale.whitelist) {
            return false;
        }

        // Check whitelist timing
        return initialSale.whitelistUntil == 0 || block.timestamp < initialSale.whitelistUntil;
    }

    /// @notice Checks if a user can buy a release and determines the maximum amount they can buy
    /// @dev Considers whitelist status, initial sale status, and transaction limits
    /// @param _releaseId The ID of the release
    /// @param _buyer The address of the buyer
    /// @return buyAllowed True if the user can buy the release, false otherwise
    /// @return maxBuyAmount The maximum amount the user can buy (0 if not allowed)
    function canBuy(uint256 _releaseId, address _buyer) public view returns (bool buyAllowed, uint256 maxBuyAmount) {
        AppSettings storage $ = appSettings;
        IGildiExchangeOrderBook orderBook = $.orderBook;

        // Check release is active
        if (!releases[_releaseId].active) {
            return (false, 0);
        }

        // Check whitelist requirements
        bool isWhitelist = isWhitelistSale(_releaseId);
        if (isWhitelist && !isInitialSaleWhitelistBuyer[_releaseId][_buyer]) {
            return (false, 0);
        }

        bool inInitialSale = isInInitialSale(_releaseId);
        if (!inInitialSale) {
            // Regular sale case - always allowed up to transaction limit
            return (true, Math.min($.maxBuyPerTransaction, orderBook.getAvailableBuyQuantity(_releaseId, _buyer)));
        }

        // Initial sale timing check
        InitialSale storage initialSale = initialSales[_releaseId];
        if (block.timestamp < initialSale.startTime) {
            return (false, 0);
        }

        // Initial sale without limit
        if (initialSale.maxBuy == 0) {
            return (true, Math.min($.maxBuyPerTransaction, orderBook.getAvailableBuyQuantity(_releaseId, _buyer)));
        }

        // Check user buy limit
        uint256 userBought = initialSaleMaxBuyCounts[_releaseId][_buyer];
        if (userBought >= initialSale.maxBuy) {
            return (false, 0);
        }

        // User can buy the remaining amount up to transaction limit
        return (true, Math.min(initialSale.maxBuy - userBought, Math.min($.maxBuyPerTransaction, orderBook.getAvailableBuyQuantity(_releaseId, _buyer))));
    }

    /// @notice Checks whether or not a list of releases can be sold.
    /// @param _releaseIds The IDs of the releases
    /// @return result An array containing whether or not each release can be sold
    function canSell(uint256[] calldata _releaseIds) external view returns (bool[] memory) {
        bool[] memory result = new bool[](_releaseIds.length);
        for (uint256 i = 0; i < _releaseIds.length; i++) {
            uint256 releaseId = _releaseIds[i];
            Release storage release = releases[releaseId];
            result[i] = release.initialized && release.active && !release.isCancelling && !isInInitialSale(releaseId);
        }
        return result;
    }

    /// @notice Gets a release by ID
    /// @param _releaseId The ID of the release
    /// @return release The release
    function getReleaseById(uint256 _releaseId) external view returns (Release memory) {
        return releases[_releaseId];
    }

    /// @notice Gets the initial sale by release ID
    /// @param _releaseId The ID of the release
    /// @return initialSale The initial sale
    function getInitialSaleByReleaseId(uint256 _releaseId) external view returns (InitialSale memory) {
        return initialSales[_releaseId];
    }

    /// @inheritdoc IGildiExchange
    function getReleaseIds(bool _activeOnly) external view override returns (uint256[] memory) {
        if (!_activeOnly) {
            return releaseIds;
        }

        // Single-pass algorithm to count and collect active releases simultaneously
        uint256[] memory tempReleaseIds = new uint256[](releaseIds.length);
        uint256 activeCount = 0;

        // Store length to avoid multiple storage reads
        uint256 totalLength = releaseIds.length;

        for (uint256 i = 0; i < totalLength; i++) {
            uint256 releaseId = releaseIds[i];
            if (releases[releaseId].active || initialSales[releaseId].active) {
                tempReleaseIds[activeCount] = releaseId;
                activeCount++;
            }
        }

        // Copy to exactly-sized result array
        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = tempReleaseIds[i];
        }

        return result;
    }

    /// @inheritdoc IGildiExchange
    function getAppEnvironment() external view override returns (AppEnvironment memory) {
        return AppEnvironment(appSettings, BASIS_POINTS, ADMIN_ROLE, MARKETPLACE_MANAGER_ROLE, CLAIMER_ROLE);
    }

    /// @inheritdoc IGildiExchange
    function getActiveMarketplaceReleaseAsset(uint256 _releaseId) public view override returns (address) {
        InitialSale storage initialSale = initialSales[_releaseId];

        if (isInInitialSale(_releaseId) && initialSale.saleCurrency != address(0)) {
            return initialSale.saleCurrency;
        }

        return address(appSettings.marketplaceCurrency);
    }

    /// @notice Converts a price in USD to the equivalent amount in the release's active marketplace asset
    /// @param _releaseId The ID of the release
    /// @param _priceInUsd The price in USD to convert
    /// @return activeMarketplaceReleaseAsset The address of the active marketplace asset for the release
    /// @return priceInAsset The equivalent amount in the active marketplace asset
    function quotePrice(
        uint256 _releaseId,
        uint256 _priceInUsd
    ) external view returns (address activeMarketplaceReleaseAsset, uint256 priceInAsset) {
        AppSettings storage $ = appSettings;
        activeMarketplaceReleaseAsset = getActiveMarketplaceReleaseAsset(_releaseId);
        priceInAsset = $.paymentProcessor.quoteInCurrency(_priceInUsd, activeMarketplaceReleaseAsset);
    }

    // ========== Internal Functions ==========

    /// @dev Validates that a release is in a valid state for operations
    /// @dev Reverts with ReleaseStateError if the release is not initialized, is cancelling, or is not active
    /// @param _releaseId The ID of the release to validate
    function _validateReleaseState(uint256 _releaseId) internal view {
        Release storage release = releases[_releaseId];
        if (!release.initialized || release.isCancelling || !release.active) {
            revert ReleaseStateError(_releaseId);
        }
    }

    /// @dev Validates that a release is initialized
    /// @dev Reverts with ReleaseStateError if the release is not initialized
    /// @param _releaseId The ID of the release to validate
    function _validateReleaseInitialized(uint256 _releaseId) internal view {
        if (!releases[_releaseId].initialized) {
            revert ReleaseStateError(_releaseId);
        }
    }

    /// @dev Performs the purchase of tokens from a release
    /// @dev Handles the entire purchase flow including finding listings, transferring funds, and updating state
    /// @param _releaseId The ID of the release to purchase
    /// @param _operator The address performing the purchase operation
    /// @param _maxTotalPrice The maximum total price the buyer is willing to pay
    /// @param _amount The amount of tokens to purchase
    /// @param _buyer The address of the buyer receiving the tokens
    /// @param _isProxyOperation Whether this is a proxy operation
    /// @return amountSpent The total amount spent on the purchase
    /// @return amountUsdSpent The total amount spent in USD
    function _performPurchase(
        uint256 _releaseId,
        address _operator,
        uint256 _maxTotalPrice,
        uint256 _amount,
        address _buyer,
        bool _isProxyOperation
    ) internal returns (uint256 amountSpent, uint256 amountUsdSpent) {
        _endInitialSaleIfNecessary(_releaseId);

        AppSettings storage $ = appSettings;
        address releaseAsset = getActiveMarketplaceReleaseAsset(_releaseId);

        // Validate release state
        _validateReleaseState(_releaseId);

        // Check available buy quantity using the order book
        uint256 availableQuantity = $.orderBook.getAvailableBuyQuantity(_releaseId, _buyer);
        if (availableQuantity < _amount) {
            revert NotEnoughTokensInListings(_amount, availableQuantity);
        }

        bool releaseIsInInitialSale = isInInitialSale(_releaseId);

        // Initialize tracking variables
        uint256 remainingAmount = _amount;
        uint256 totalBought = 0;
        uint256 totalPriceInMarketplaceCurrency = 0;
        uint256 totalPriceInUsd = 0;

        // Process listings in order of price
        uint256 current = $.orderBook.getHeadListingId(_releaseId);
        while (current != 0 && remainingAmount > 0) {
            // Get the listing details
            IGildiExchangeOrderBook.Listing memory listing = $.orderBook.getListing(current);

            // Skip self-listings
            if (listing.seller == _buyer) {
                current = $.orderBook.getNextListingId(current);
                continue;
            }

            // Calculate quantity to buy from this listing
            uint256 boughtQuantity = listing.quantity >= remainingAmount ? remainingAmount : listing.quantity;
            remainingAmount -= boughtQuantity;

            // Calculate price and process payment
            uint256 marketplaceCurrencyPricePerItem = $.paymentProcessor.quoteInCurrency(
                listing.pricePerItem,
                releaseAsset
            );
            uint256 listingPrice = marketplaceCurrencyPricePerItem * boughtQuantity;
            uint256 listingUsdPrice = listing.pricePerItem * boughtQuantity;
            _handlePaymentFlow(
                _operator,
                _buyer,
                listing.fundsReceiver == address(0) ? listing.seller : listing.fundsReceiver,
                _releaseId,
                listingPrice,
                releaseAsset,
                _isProxyOperation,
                listing.id,
                listing.payoutCurrency,
                listing.slippageBps
            );
            totalPriceInMarketplaceCurrency += listingPrice;
            totalPriceInUsd += listingUsdPrice;

            // Unlock tokens
            $.gildiManager.unlockTokens(listing.seller, listing.releaseId, boughtQuantity);

            // Transfer ownership using appropriate method based on sale state
            if (releaseIsInInitialSale) {
                $.gildiManager.transferOwnershipInitialSale(_releaseId, listing.seller, _buyer, boughtQuantity);
            } else {
                $.gildiManager.transferOwnership(_releaseId, listing.seller, _buyer, boughtQuantity);
            }

            // Log events
            emit Purchased(
                _releaseId,
                _buyer,
                listing.seller,
                _operator,
                listing.id,
                listing.pricePerItem,
                boughtQuantity,
                marketplaceCurrencyPricePerItem,
                releaseAsset
            );

            // Update totals
            totalBought += boughtQuantity;

            // Get next listing before modifying current one
            uint256 nextId = $.orderBook.getNextListingId(current);

            // Update the orderbook
            $.orderBook.handleDecreaseListingQuantity(current, boughtQuantity);

            current = nextId;
        }

        // Ensure price limit wasn't exceeded
        if (totalPriceInMarketplaceCurrency > _maxTotalPrice) {
            revert PurchaseError();
        }

        // Ensure all requested tokens were purchased
        if (remainingAmount > 0) {
            revert NotEnoughTokensInListings(_amount, _amount - remainingAmount);
        }

        // Handle initial sale bookkeeping if needed
        if (releaseIsInInitialSale) {
            initialSaleListedQuantities[_releaseId] -= totalBought;
            initialSaleMaxBuyCounts[_releaseId][_buyer] += _amount;

            if ($.orderBook.listedQuantities(_releaseId) == 0) {
                _endInitialSale(_releaseId);
            }
        }

        return (totalPriceInMarketplaceCurrency, totalPriceInUsd);
    }

    /// @dev Ends the initial sale for a release
    /// @dev Cleans up all initial sale data including whitelist information
    /// @param _releaseId The ID of the release to end initial sale for
    function _endInitialSale(uint256 _releaseId) internal {
        AppSettings storage $ = appSettings;
        address[] storage buyers = initialSaleWhitelistBuyers[_releaseId];
        uint256 buyersLength = buyers.length;

        // Reset all initial sale data in one go
        delete initialSales[_releaseId];

        // Clean up whitelist data - use single loop
        for (uint256 i = 0; i < buyersLength; i++) {
            address buyer = buyers[i];
            delete isInitialSaleWhitelistBuyer[_releaseId][buyer];
            delete initialSaleMaxBuyCounts[_releaseId][buyer];
        }

        delete initialSaleWhitelistBuyers[_releaseId];
        delete initialSaleListedQuantities[_releaseId];

        if ($.gildiManager.isInInitialSale(_releaseId)) {
            $.gildiManager.endInitialSale(_releaseId);
        }

        emit InitialSaleEnded(_releaseId);
    }

    /// @dev Creates a new listing
    /// @param _releaseId The ID of the release
    /// @param _seller The address of the seller
    /// @param _pricePerItem The price per item (in USD)
    /// @param _quantity The quantity of the listing
    /// @param _payoutCurrency The currency to payout in
    /// @param _fundsReceiver The address to receive funds from the sale (if address(0), defaults to seller)
    /// @param _slippageBps The slippage tolerance in basis points
    function _createListing(
        uint256 _releaseId,
        address _seller,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) internal nonReentrant {
        _endInitialSaleIfNecessary(_releaseId);

        AppSettings storage $ = appSettings;
        Release storage release = releases[_releaseId];

        // Only the seller or someone with ADMIN_ROLE can create a listing
        if (_seller != _msgSender() && !hasRole(ADMIN_ROLE, _msgSender())) {
            revert SharedErrors.NotAllowed();
        }

        // Validation
        if (release.isCancelling || !release.active) {
            revert ReleaseStateError(_releaseId);
        }

        if ($.gildiManager.isLocked(_releaseId)) {
            revert ReleaseStateError(_releaseId);
        }

        if ($.gildiManager.isInInitialSale(_releaseId) && isInInitialSale(_releaseId)) {
            revert ReleaseStateError(_releaseId);
        }

        if (_slippageBps > BASIS_POINTS) {
            revert SharedErrors.ParamError();
        }

        // Delegate to the order book
        $.orderBook.handleCreateListing(
            _releaseId,
            _seller,
            _pricePerItem,
            _quantity,
            _payoutCurrency,
            _fundsReceiver,
            _slippageBps
        );
    }

    /// @dev Modifies an existing listing
    /// @param _listingId The ID of the listing
    /// @param _newPricePerItem The new price per item (in USD)
    /// @param _newQuantity The new quantity of the listing
    /// @param _payoutCurrency The new payout currency
    /// @param _fundsReceiver The new address to receive funds from the sale (if address(0), defaults to seller)
    /// @param _slippageBps The new slippage tolerance in basis points
    function _modifyListing(
        uint256 _listingId,
        uint256 _newPricePerItem,
        uint256 _newQuantity,
        address _payoutCurrency,
        address _fundsReceiver,
        uint16 _slippageBps
    ) internal nonReentrant {
        _endInitialSaleIfNecessary(_listingId);

        AppSettings storage $ = appSettings;

        // Get the listing from the order book
        IGildiExchangeOrderBook.Listing memory listing = $.orderBook.getListing(_listingId);

        // Only the listing owner or someone with ADMIN_ROLE can modify a listing
        if (listing.seller != _msgSender() && !hasRole(ADMIN_ROLE, _msgSender())) {
            revert SharedErrors.NotAllowed();
        }

        if ($.gildiManager.isInInitialSale(listing.releaseId) && isInInitialSale(listing.releaseId)) {
            revert ReleaseStateError(listing.releaseId);
        }

        if (_slippageBps > BASIS_POINTS) {
            revert SharedErrors.ParamError();
        }

        // Delegate to the order book
        $.orderBook.handleModifyListing(
            _listingId,
            _newPricePerItem,
            _newQuantity,
            _payoutCurrency,
            _fundsReceiver,
            _slippageBps
        );
    }

    /// @dev Handles currency transfers between buyers and sellers
    /// @dev Determines whether to use fund or direct transfer based on initial sale status
    /// @param _operator The address of the operator
    /// @param _buyer The address of the buyer
    /// @param _seller The address of the seller
    /// @param _releaseId The ID of the release
    /// @param _value The value to transfer
    /// @param _currencyAddress The address of the currency to transfer
    /// @param _isProxyOperation Whether this is a proxy operation
    /// @param _listingId The ID of the listing
    /// @param _payoutCurrency The currency to payout in
    /// @param _slippageBps The slippage tolerance in basis points
    function _handlePaymentFlow(
        address _operator,
        address _buyer,
        address _seller,
        uint256 _releaseId,
        uint256 _value,
        address _currencyAddress,
        bool _isProxyOperation,
        uint256 _listingId,
        address _payoutCurrency,
        uint16 _slippageBps
    ) internal {
        _validateReleaseInitialized(_releaseId);

        AppSettings storage $ = appSettings;

        bool isFund = isInInitialSale(_releaseId);

        if (isFund) {
            // Process fees and create funds, passing the proxy operation flag
            $.paymentProcessor.handleProcessPaymentWithFees(
                _releaseId,
                _buyer,
                _seller,
                _value,
                _currencyAddress,
                true,
                _operator,
                _isProxyOperation,
                _listingId,
                _payoutCurrency,
                _slippageBps
            );
        } else {
            // Process fees and make direct transfers
            // For direct transfers we don't need to track the proxy operation flag
            $.paymentProcessor.handleProcessPaymentWithFees(
                _releaseId,
                _buyer,
                _seller,
                _value,
                _currencyAddress,
                false, // _createFund
                _operator, // Use the actual operator, not the buyer
                false, // _isProxyOperation
                _listingId,
                _payoutCurrency,
                _slippageBps
            );
        }
    }

    /// @dev Validates that fee distributions are valid
    /// @dev Ensures that fee percentages don't exceed 100% (BASIS_POINTS) for both parent and sub-fees
    /// @param _feeDistributions Array of fee distributions to validate
    function _enforceValidFeeDistribution(FeeDistribution[] memory _feeDistributions) internal pure {
        uint256 sum = 0;
        uint256 feeLength = _feeDistributions.length;

        for (uint256 i = 0; i < feeLength; i++) {
            // Add parent fee, check immediately
            sum += _feeDistributions[i].feeReceiver.value;
            if (sum > BASIS_POINTS) {
                revert SetupError();
            }

            // Check sub fees in a separate loop
            uint256 subSum = 0;
            uint256 subLength = _feeDistributions[i].subFeeReceivers.length;

            for (uint256 j = 0; j < subLength; j++) {
                subSum += _feeDistributions[i].subFeeReceivers[j].value;
            }

            if (subSum > BASIS_POINTS) {
                revert SetupError();
            }
        }
    }

    /// @dev Checks if an initial sale should be ended and ends it if necessary
    /// @dev Ends the initial sale if it's active but no longer in the initial sale period
    /// @param _releaseId The ID of the release to check
    function _endInitialSaleIfNecessary(uint256 _releaseId) internal {
        if (initialSales[_releaseId].active && !isInInitialSale(_releaseId)) {
            _endInitialSale(_releaseId);
        }
    }

    /// @dev Sets the marketplace currency
    /// @param _marketplaceCurrency The address of the marketplace currency
    function _setMarketplaceCurrency(address _marketplaceCurrency) private {
        AppSettings storage $ = appSettings;
        $.marketplaceCurrency = IERC20(_marketplaceCurrency);

        emit MarketplaceCurrencySet(_marketplaceCurrency);
    }

    // ---------------------------------------------------------------------------
    // End of contract logic
    // ---------------------------------------------------------------------------

    // ---------------------------------------------------------------------------
    // Fallback functions
    // ---------------------------------------------------------------------------

    /// @notice Fallback function to prevent direct Ether transfers
    fallback() external payable {
        revert SharedErrors.NotAllowed();
    }

    /// @notice Fallback function to prevent direct Ether transfers
    receive() external payable {
        revert SharedErrors.NotAllowed();
    }
}
