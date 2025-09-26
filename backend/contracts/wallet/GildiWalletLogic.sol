// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {StorageSlot} from '@openzeppelin/contracts/utils/StorageSlot.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IGildiExchange} from '../interfaces/marketplace/exchange/IGildiExchange.sol';
import {IGildiExchangePaymentAggregator} from '../interfaces/marketplace/exchange/IGildiExchangePaymentAggregator.sol';
import {IGildiExchangePurchaseVault} from '../interfaces/marketplace/vault/IGildiExchangePurchaseVault.sol';
import {RoyaltyDistributor} from '../royalties/RoyaltyDistributor.sol';
import {IGildiManager} from '../interfaces/manager/IGildiManager.sol';
import {IGildiWalletConfigRegistry} from '../interfaces/wallet/IGildiWalletConfigRegistry.sol';

/// @title GildiWalletLogic
/// @notice Gildi proxy wallets business logic
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiWalletLogic is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for operator accounts that can execute certain business functions
    bytes32 public constant OPERATOR_ROLE = keccak256('OPERATOR_ROLE');

    /// @notice Version of this logic contract implementation
    uint256 public constant VERSION = 10000;

    /// @dev Storage slot for off-ramp guard mechanism to verify call path originates from proxy
    bytes32 private constant OFFRAMP_GUARD_SLOT = 0xbf2e87ae6cef65f01e1c587276c96bbd9fc7ff1493647120ef7d93bf473a6640;
    /// @dev Storage slot for wallet configuration to ensure future extensibility
    bytes32 private constant WALLET_CONFIG_SLOT = 0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b;

    enum WithdrawType {
        WITHDRAW_TYPE_CRYPTO_WALLET,
        WITHDRAW_TYPE_TRANSAK_STREAM
    }

    /// @notice Versioned wallet configuration snapshot stored in the wallet.
    /// @dev Holds a pointer to the registry and the active resolved configuration.
    struct VersionedWalletConfig {
        /// @dev Address of the configuration registry contract
        address configRegistry;
        /// @dev Local version of the applied configuration (compared to implementation VERSION)
        uint256 version;
        /// @dev Resolved configuration values used by this wallet
        IGildiWalletConfigRegistry.WalletConfig config;
    }

    /// @notice Parameters for Transak stream withdrawal flow.
    struct WithdrawTransakParams {
        /// @dev Destination wallet that accepts Transak stream deposits
        address transakStreamWallet;
        /// @dev Token to stream; must be a Transak-supported asset
        address transakStreamToken; // Need to swap to a transak stream supported token.
    }

    /// @dev Thrown when attempting to initialize with a zero address for owner
    error ZeroOwnerAddress();

    /// @dev Thrown when off-ramp function is called through invalid entry point
    error InvalidEntryPoint();

    /// @dev No remaining USD in the referenced intent
    error NoRemainingUsd();
    /// @dev Estimated cost exceeds remaining USD in the intent
    error EstimatedCostExceedsIntent();
    /// @dev Actual cost exceeds remaining USD in the intent
    error ActualCostExceedsIntent();
    /// @dev Provided arrays have mismatched lengths
    error ArraysLengthMismatch();
    /// @dev Invalid data payload provided for Transak withdrawal
    error InvalidTransakData();
    /// @dev Invalid data payload provided for address-based withdrawal
    error InvalidAddressData();
    /// @dev Invalid withdraw type selector
    error InvalidWithdrawType();
    /// @dev Zero address provided for recipient
    error ZeroAddressRecipient();
    /// @dev Invalid Transak wallet address
    error InvalidTransakWallet();
    /// @dev Invalid Transak token address
    error InvalidTransakToken();
    /// @dev Feature not yet implemented
    error TransakWithdrawalNotImplemented();
    /// @dev Configuration errors
    error GildiManagerNotConfigured();
    error RoyaltyDistributorNotConfigured();
    error GildiExchangeNotConfigured();
    error PaymentAggregatorNotConfigured();
    error PurchaseVaultNotConfigured();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the wallet logic with owner and operator roles, to be called from the factory.
    /// @dev This function can only be called once due to the initializer modifier
    /// @param _owner The address that will receive the DEFAULT_ADMIN_ROLE
    /// @param _operator The address that will receive the OPERATOR_ROLE (can be zero address)
    function initialize(address _owner, address _operator, address _configRegistry) public initializer {
        if (_owner == address(0)) {
            revert ZeroOwnerAddress();
        }

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        if (_operator != address(0)) {
            _grantRole(OPERATOR_ROLE, _operator);
        }

        // Initialize wallet config storage
        VersionedWalletConfig storage $ = _getWalletConfigStorage();
        $.configRegistry = _configRegistry;

        // Initialize with default config (version 0) from registry
        if (_configRegistry != address(0)) {
            IGildiWalletConfigRegistry registry = IGildiWalletConfigRegistry(_configRegistry);
            $.config = registry.getDefaultConfig();
            $.version = 0; // Start with default config version
        }
    }

    /// @dev Internal function to get config with version check and update
    function _getWalletConfigWithUpdate() internal returns (IGildiWalletConfigRegistry.WalletConfig memory config) {
        return _getWalletConfig();
    }

    /// @notice Migrates configuration from registry (manual trigger)
    /// @dev Can be called to force migration from registry
    function migrateConfigFromRegistry() external {
        _getWalletConfigWithUpdate();
    }

    // ========== Marketplace Functions ==========

    /// @notice Creates a listing with default slippage on the marketplace
    /// @dev Only callable by accounts with OPERATOR_ROLE
    /// @param _releaseId The ID of the release
    /// @param _pricePerItem The price per item in USD
    /// @param _quantity The quantity being listed
    /// @param _payoutCurrency The currency the seller wants to receive payment in
    /// @param _fundsReceiver The address to receive funds from the sale (if address(0), defaults to seller)
    function createListing(
        uint256 _releaseId,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external onlyRole(OPERATOR_ROLE) {
        IGildiExchange exchange = _getGildiExchange();

        exchange.createListing(_releaseId, address(this), _pricePerItem, _quantity, _payoutCurrency, _fundsReceiver);
    }

    /// @notice Modifies an existing listing with default slippage on the marketplace
    /// @dev Only callable by accounts with OPERATOR_ROLE
    /// @param _listingId The ID of the listing to modify
    /// @param _pricePerItem The new price per item in USD
    /// @param _quantity The new quantity (if 0, the listing will be removed)
    /// @param _payoutCurrency The new payout currency
    function modifyListing(
        uint256 _listingId,
        uint256 _pricePerItem,
        uint256 _quantity,
        address _payoutCurrency,
        address _fundsReceiver
    ) external onlyRole(OPERATOR_ROLE) {
        IGildiExchange exchange = _getGildiExchange();

        exchange.modifyListing(_listingId, _pricePerItem, _quantity, _payoutCurrency, _fundsReceiver);
    }

    /// @notice Cancels a listing on the marketplace
    /// @dev Only callable by accounts with OPERATOR_ROLE
    /// @param _listingId The ID of the listing to cancel
    function cancelListing(uint256 _listingId) external onlyRole(OPERATOR_ROLE) {
        IGildiExchange exchange = _getGildiExchange();

        exchange.cancelListing(_listingId);
    }

    /// @notice Claims all available royalty distributions for this wallet across all releases
    /// @dev Uses RoyaltyDistributor to claim all available distributions
    function claimAllRoyalties() external onlyRole(OPERATOR_ROLE) {
        RoyaltyDistributor distributor = _getRoyaltyDistributor();
        distributor.claimAll();
    }

    /// @notice Claims royalty distributions for this wallet from a specific release
    /// @param _releaseId The ID of the release to claim royalties from
    function claimReleaseRoyalties(uint256 _releaseId) external onlyRole(OPERATOR_ROLE) {
        RoyaltyDistributor distributor = _getRoyaltyDistributor();
        distributor.claimAllByReleaseId(_releaseId);
    }

    /// @notice Claims a specific royalty distribution
    /// @param _distributionId The ID of the distribution to claim
    function claimRoyalties(uint256 _distributionId) external onlyRole(OPERATOR_ROLE) {
        RoyaltyDistributor distributor = _getRoyaltyDistributor();
        distributor.claim(_distributionId);
    }

    /// @notice Purchases tokens from a release using vault-based USD treasury system (fill or kill)
    /// @dev Only callable by accounts with OPERATOR_ROLE. Works exclusively through vault.
    /// @param _intentId The purchase intent ID from the vault
    /// @param _releaseId The release ID to purchase from
    /// @param _amount The amount of tokens to purchase
    /// @param _tokenHint An optional token hint to use for purchase
    function purchase(
        bytes32 _intentId,
        uint256 _releaseId,
        uint256 _amount,
        address _tokenHint
    ) external onlyRole(OPERATOR_ROLE) {
        IGildiExchangePurchaseVault vault = _getPurchaseVault();
        IGildiExchangePaymentAggregator aggregator = _getPaymentAggregator();

        // 1. Check remaining USD from intent (must be > 0)
        uint256 remainingUsdCents = vault.remainingUsd(_intentId);
        if (remainingUsdCents == 0) {
            revert NoRemainingUsd();
        }

        // 2. Execute intent to get tokens from vault
        (address vaultToken, uint256 tokenAmount) = vault.executeIntent(
            _intentId,
            _tokenHint,
            IGildiExchangePurchaseVault.ExecutionContext({releaseId: _releaseId, amount: _amount, buyer: address(this)})
        );

        // 3. Estimate purchase cost and validate against intent balance
        (, , , uint256 totalPriceUsdExchange) = aggregator.estimatePurchase(
            _releaseId,
            _amount,
            address(this),
            vaultToken
        );
        uint256 estimatedCostCents = _convertExchangeUsdToCents(totalPriceUsdExchange);

        if (estimatedCostCents > remainingUsdCents) {
            revert EstimatedCostExceedsIntent();
        }

        // 4. Approve tokens to aggregator (zero-reset pattern for USDT-style tokens)
        IERC20(vaultToken).forceApprove(address(aggregator), tokenAmount);

        // 5. Track vault token balance before purchase to detect refunds
        uint256 vaultTokenBalanceBefore = IERC20(vaultToken).balanceOf(address(this)) - tokenAmount;

        // 6. Execute marketplace purchase and get actual USD spent
        uint256 actualUsdSpentExchangeDecimals = aggregator.purchase(_releaseId, _amount, vaultToken, tokenAmount);
        // Clear aggregator allowance after use
        IERC20(vaultToken).approve(address(aggregator), 0);

        // 7. Check for leftover vault tokens returned by aggregator
        uint256 vaultTokenBalanceAfter = IERC20(vaultToken).balanceOf(address(this));

        address refundToken = address(0);
        uint256 refundTokenAmount = 0;

        if (vaultTokenBalanceAfter > vaultTokenBalanceBefore) {
            refundTokenAmount = vaultTokenBalanceAfter - vaultTokenBalanceBefore;
            refundToken = vaultToken;

            // Approve vault to take back the leftover tokens (zero-reset pattern)
            IERC20(vaultToken).forceApprove(address(vault), refundTokenAmount);
        }

        // 8. Convert actual USD spent to vault cents and settle intent with refund info
        uint256 actualUsdSpentCents = _convertExchangeUsdToCents(actualUsdSpentExchangeDecimals);

        if (actualUsdSpentCents > remainingUsdCents) {
            revert ActualCostExceedsIntent();
        }

        vault.settleIntent(_intentId, actualUsdSpentCents, refundToken, refundTokenAmount);

        // Clear vault allowance after settlement (if any)
        if (refundToken != address(0) && refundTokenAmount > 0) {
            IERC20(refundToken).approve(address(vault), 0);
        }
    }

    /// @notice Withdraws multiple tokens from the wallet to a specified beneficiary
    /// @dev Allows batch withdrawal of different tokens and amounts
    /// @param _tokens Array of token contract addresses to withdraw
    /// @param _amounts Array of amounts to withdraw (must match tokens array length)
    /// @param _data The data to pass to the withdraw function
    function withdrawFunds(
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        WithdrawType _withdrawType,
        bytes calldata _data
    ) external onlyRole(OPERATOR_ROLE) {
        if (_tokens.length != _amounts.length) {
            revert ArraysLengthMismatch();
        }

        if (_withdrawType == WithdrawType.WITHDRAW_TYPE_TRANSAK_STREAM) {
            if (_data.length == 0) {
                revert InvalidTransakData();
            }
            WithdrawTransakParams memory params = abi.decode(_data, (WithdrawTransakParams));
            _handleWithdrawTransak(params, _tokens, _amounts);
        } else if (_withdrawType == WithdrawType.WITHDRAW_TYPE_CRYPTO_WALLET) {
            if (_data.length != 32) {
                revert InvalidAddressData();
            }
            address to = abi.decode(_data, (address));
            _handleWithdrawCryptoWallet(to, _tokens, _amounts);
        } else {
            revert InvalidWithdrawType();
        }
    }

    function _handleWithdrawTransak(
        WithdrawTransakParams memory _params,
        address[] calldata /* _tokens */,
        uint256[] calldata /* _amounts */
    ) private pure {
        if (_params.transakStreamWallet == address(0)) {
            revert InvalidTransakWallet();
        }
        if (_params.transakStreamToken == address(0)) {
            revert InvalidTransakToken();
        }

        // TODO: Implement token swapping logic and Transak stream integration
        // For now, revert to prevent unintended usage
        revert TransakWithdrawalNotImplemented();
    }

    function _handleWithdrawCryptoWallet(address _to, address[] calldata _tokens, uint256[] calldata _amounts) private {
        if (_to == address(0)) {
            revert ZeroAddressRecipient();
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_amounts[i] > 0) {
                IERC20(_tokens[i]).safeTransfer(_to, _amounts[i]);
            }
        }
    }

    // ========== GildiManager Functions ==========

    /// @notice Transfers right ownership of tokens within GildiManager from this wallet to another address
    /// @dev Only callable by accounts with OPERATOR_ROLE
    /// @param _releaseId The ID of the release
    /// @param _to The address to transfer right ownership to
    /// @param _amount The amount of right shares to transfer
    function transferRightOwnership(uint256 _releaseId, address _to, uint256 _amount) external onlyRole(OPERATOR_ROLE) {
        IGildiManager manager = _getGildiManager();
        manager.transferOwnership(_releaseId, address(this), _to, _amount);
    }

    // ========== Internal functions ==========
    function _getWalletConfigStorage() internal pure returns (VersionedWalletConfig storage $) {
        assembly {
            $.slot := WALLET_CONFIG_SLOT
        }
    }

    function _getWalletConfig() internal returns (IGildiWalletConfigRegistry.WalletConfig memory) {
        VersionedWalletConfig storage $ = _getWalletConfigStorage();

        // Update logic...
        if (address($.configRegistry) != address(0)) {
            IGildiWalletConfigRegistry registry = IGildiWalletConfigRegistry($.configRegistry);
            // Always fetch the best available config for our version
            if ($.version != VERSION) {
                $.config = registry.getConfigForVersion(VERSION);
                $.version = VERSION; // Update version after migration
            }
        }

        return $.config;
    }

    function _getGildiManager() internal returns (IGildiManager) {
        IGildiWalletConfigRegistry.WalletConfig memory config = _getWalletConfig();
        if (config.gildiManager == address(0)) {
            revert GildiManagerNotConfigured();
        }
        return IGildiManager(config.gildiManager);
    }

    function _getRoyaltyDistributor() internal returns (RoyaltyDistributor) {
        IGildiWalletConfigRegistry.WalletConfig memory config = _getWalletConfig();
        if (config.royaltyDistributor == address(0)) {
            revert RoyaltyDistributorNotConfigured();
        }
        return RoyaltyDistributor(config.royaltyDistributor);
    }

    function _getGildiExchange() internal returns (IGildiExchange) {
        IGildiWalletConfigRegistry.WalletConfig memory config = _getWalletConfig();
        if (config.gildiExchange == address(0)) {
            revert GildiExchangeNotConfigured();
        }
        return IGildiExchange(config.gildiExchange);
    }

    function _getPaymentAggregator() internal returns (IGildiExchangePaymentAggregator) {
        IGildiWalletConfigRegistry.WalletConfig memory config = _getWalletConfig();
        if (config.paymentAggregator == address(0)) {
            revert PaymentAggregatorNotConfigured();
        }
        return IGildiExchangePaymentAggregator(config.paymentAggregator);
    }

    function _getPurchaseVault() internal returns (IGildiExchangePurchaseVault) {
        IGildiWalletConfigRegistry.WalletConfig memory config = _getWalletConfig();
        if (config.purchaseVault == address(0)) {
            revert PurchaseVaultNotConfigured();
        }
        return IGildiExchangePurchaseVault(config.purchaseVault);
    }

    /// @dev Internal function to convert USD from exchange decimals to cents
    function _convertExchangeUsdToCents(uint256 _usdPriceExchangeDecimals) internal returns (uint256 usdCents) {
        IGildiExchange exchange = _getGildiExchange();
        IGildiExchange.AppEnvironment memory env = exchange.getAppEnvironment();
        uint8 exchangeDecimals = env.settings.priceAskDecimals;

        // Convert from exchange decimals to cents (2 decimals)
        if (exchangeDecimals >= 2) {
            usdCents = _usdPriceExchangeDecimals / (10 ** (exchangeDecimals - 2));
        } else {
            usdCents = _usdPriceExchangeDecimals * (10 ** (2 - exchangeDecimals));
        }
    }

    /// @dev Internal function to convert USD from cents to exchange decimals
    function _convertCentsToExchangeUsd(uint256 _usdCents) internal returns (uint256 usdExchangeDecimals) {
        IGildiExchange exchange = _getGildiExchange();
        IGildiExchange.AppEnvironment memory env = exchange.getAppEnvironment();
        uint8 exchangeDecimals = env.settings.priceAskDecimals;

        // Convert from cents (2 decimals) to exchange decimals
        if (exchangeDecimals >= 2) {
            usdExchangeDecimals = _usdCents * (10 ** (exchangeDecimals - 2));
        } else {
            usdExchangeDecimals = _usdCents / (10 ** (2 - exchangeDecimals));
        }
    }

    /// @dev Removes operator role from specified address when called through proxy's guarded flow
    /// @param _operator The operator address to remove role from
    function offRampOperator(address _operator) external {
        // Only callable via proxy's guarded flow
        if (!StorageSlot.getBooleanSlot(OFFRAMP_GUARD_SLOT).value) {
            revert InvalidEntryPoint();
        }
        // Revoke operator role if currently granted; bypass external access checks using internal hook
        if (_operator != address(0) && hasRole(OPERATOR_ROLE, _operator)) {
            _revokeRole(OPERATOR_ROLE, _operator);
        }
    }

    /// @dev Updates admin role when called through proxy's guarded flow
    /// @param _oldAdmin The old admin address to remove role from
    /// @param _newAdmin The new admin address to grant role to
    function offRampUpdateAdmin(address _oldAdmin, address _newAdmin) external {
        // Only callable via proxy's guarded flow
        if (!StorageSlot.getBooleanSlot(OFFRAMP_GUARD_SLOT).value) {
            revert InvalidEntryPoint();
        }
        // Remove old admin role if currently granted
        if (_oldAdmin != address(0) && hasRole(DEFAULT_ADMIN_ROLE, _oldAdmin)) {
            _revokeRole(DEFAULT_ADMIN_ROLE, _oldAdmin);
        }
        // Grant new admin role
        if (_newAdmin != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, _newAdmin);
        }
    }

    /// @dev Updates operator role when called through proxy's guarded flow
    /// @param _oldOperator The old operator address to remove role from
    /// @param _newOperator The new operator address to grant role to
    function offRampUpdateOperator(address _oldOperator, address _newOperator) external {
        // Only callable via proxy's guarded flow
        if (!StorageSlot.getBooleanSlot(OFFRAMP_GUARD_SLOT).value) {
            revert InvalidEntryPoint();
        }
        // Remove old operator role if currently granted
        if (_oldOperator != address(0) && hasRole(OPERATOR_ROLE, _oldOperator)) {
            _revokeRole(OPERATOR_ROLE, _oldOperator);
        }
        // Grant new operator role
        if (_newOperator != address(0)) {
            _grantRole(OPERATOR_ROLE, _newOperator);
        }
    }
}
