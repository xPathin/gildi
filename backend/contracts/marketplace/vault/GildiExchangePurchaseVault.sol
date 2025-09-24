// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IGildiPriceOracle} from '../../interfaces/oracles/price/IGildiPriceOracle.sol';
import {IGildiPriceResolver} from '../../interfaces/oracles/price/IGildiPriceResolver.sol';
import {IGildiExchangePurchaseVault} from '../../interfaces/marketplace/vault/IGildiExchangePurchaseVault.sol';
import {IGildiExchangePaymentAggregator} from '../../interfaces/marketplace/exchange/IGildiExchangePaymentAggregator.sol';
import {IGildiExchangeSwapAdapter} from '../../interfaces/marketplace/exchange/IGildiExchangeSwapAdapter.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

/// @title USD Treasury Purchase Vault
/// @notice A vault that allows creating USD purchase intents and fulfilling them with crypto tokens
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiExchangePurchaseVault is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IGildiExchangePurchaseVault
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // -------------------- Constants --------------------
    bytes32 public constant OPERATOR_ROLE = keccak256('OPERATOR_ROLE'); // create/cancel intents
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE'); // admin

    // -------------------- Types --------------------
    enum PurchaseStatus {
        PENDING,
        FUNDED,
        SETTLED,
        EXPIRED,
        CANCELLED
    }

    /// @notice Represents a purchase intent within the vault lifecycle.
    /// @dev Captures all metadata required to validate and settle a purchase.
    struct PurchaseIntent {
        /// @dev Unique identifier for the intent
        bytes32 intentId;
        /// @dev Address authorized to execute and settle this intent
        address beneficiary;
        /// @dev Total authorized value in USD cents (2 decimals)
        uint256 valueUsd;
        /// @dev Token used for funding the purchase
        address debitedToken;
        /// @dev Amount of token debited to the beneficiary
        uint256 debitedTokenAmount;
        /// @dev Token price in USD with 18 decimals at time of debit
        uint256 debitedTokenPrice;
        /// @dev Actual USD spent (in cents, 2 decimals)
        uint256 settledUsd;
        /// @dev Unix timestamp after which the intent is no longer valid
        uint256 expiresAt;
        /// @dev Unix timestamp of intent creation
        uint256 createdAt;
        /// @dev Unix timestamp of last update
        uint256 updatedAt;
        /// @dev Stored status; EXPIRED is derived in views for pending intents past expiry
        PurchaseStatus status;
        /// @dev Block number when executeIntent was called (0 = not executed)
        uint256 executedAtBlock;
    }

    /// @notice Represents a token supported by the vault.
    struct TokenView {
        /// @dev The token address
        address token;
        /// @dev The feed ID for the token
        bytes32 feedId;
        /// @dev Whether this token is the default token
        bool defaultToken;
    }

    // -------------------- State Variables --------------------
    /// @notice Price oracle for token valuations
    IGildiPriceOracle public gildiPriceOracle;

    /// @notice Payment aggregator for purchase routing and estimation
    IGildiExchangePaymentAggregator public paymentAggregator;

    /// @notice Slippage and fee buffer in basis points (100 = 1%)
    uint256 public slippageAndFeeBuffer;

    /// @notice Preferred token to use if viable (acts as an override when set)
    address public preferredToken;

    /// @dev Supported tokens for vault operations
    EnumerableSet.AddressSet private supportedTokens;

    /// @notice Oracle feed IDs for supported tokens (token => feedId)
    mapping(address => bytes32) public tokenFeedIds;

    /// @dev Purchase intents storage
    mapping(bytes32 => PurchaseIntent) private intents;

    // -------------------- Errors --------------------
    // Intent lifecycle errors
    /// @dev Thrown when trying to create an intent that already exists
    error IntentAlreadyExists(bytes32 intentId);
    /// @dev Thrown when a referenced intent does not exist
    error IntentDoesNotExist(bytes32 intentId);
    /// @dev Thrown when an operation is invalid for the current intent state
    error IntentWrongState(bytes32 intentId);
    /// @dev Thrown when an operation is attempted on an expired intent
    error IntentExpired(bytes32 intentId);
    /// @dev Thrown when msg.sender is not the intent beneficiary
    error NotBeneficiary(bytes32 intentId);
    /// @dev Thrown when a debit would exceed remaining USD allowance
    error UsdOverDebit(bytes32 intentId, uint256 want, uint256 remaining);

    // Token and vault errors
    /// @dev Thrown when a token is not supported by the vault
    error TokenNotSupported(address token);
    /// @dev Thrown when a provided token is not allowed for the operation
    error NotAllowedToken(address token);
    /// @dev Thrown when vault balance is insufficient for the transfer
    error InsufficientVaultBalance(address token, uint256 want, uint256 have);
    /// @dev Thrown when no viable token can be found to fund a purchase
    error NoViableTokenFound(uint256 intentValueUsdCents);
    /// @dev Thrown when oracle feed ID is missing for a token
    error TokenFeedIdNotSet(address token);
    /// @dev Thrown when zero address provided where non-zero is required
    error ZeroAddressToken();

    // Refund errors
    /// @dev Thrown when attempting a refund before execution
    error RefundWithoutExecution(bytes32 intentId);
    /// @dev Thrown when refund is not performed within the same transaction as execution
    error RefundNotSameTransaction(bytes32 intentId);
    /// @dev Thrown when provided refund is insufficient to cover required delta
    error InsufficientRefund(bytes32 intentId);
    /// @dev Thrown when interacting with fee-on-transfer tokens (unsupported)
    error FeeOnTransferNotSupported(address token);

    // Configuration and validation errors
    /// @dev Thrown when price data is considered too old
    error PriceDataTooOld(uint256 age);
    /// @dev Thrown when function parameters are invalid
    error BadParams();
    /// @dev Thrown when USD credit is below the minimum threshold
    error UsdCreditTooLow(uint256 credited, uint256 minUsdCredit);
    /// @dev Thrown when ETH is sent to a non-payable function
    error EthNotAcceptedHere();

    // -------------------- Events --------------------
    // Intent lifecycle events
    /// @notice Emitted when a purchase intent is created
    event IntentCreated(bytes32 indexed intentId, address indexed beneficiary, uint256 valueUsd, uint256 expiresAt);

    /// @notice Emitted when an intent is executed
    event IntentExecuted(
        bytes32 indexed intentId,
        address indexed token,
        uint256 tokenSent,
        uint256 usdDebited,
        uint256 tokenPrice
    );

    /// @notice Emitted when intent is settled with actual USD spent
    event IntentSettled(bytes32 indexed intentId, uint256 actualUsdSpentCents);

    /// @notice Emitted when an intent is cancelled
    event IntentCancelled(bytes32 indexed intentId, uint8 reasonCode);

    // Vault management events
    /// @notice Emitted when vault is topped up with tokens
    event VaultToppedUp(address indexed token, uint256 amount, address indexed from);

    /// @notice Emitted when tokens are withdrawn from vault
    event VaultWithdrawn(address indexed token, uint256 amount, address indexed to);

    // Configuration events
    /// @notice Emitted when price oracle is updated
    event PriceOracleSet(address indexed priceOracle);

    /// @notice Emitted when payment aggregator is updated
    event PaymentAggregatorSet(address indexed paymentAggregator);

    /// @notice Emitted when slippage and fee buffer is updated
    event SlippageAndFeeBufferSet(uint256 slippageAndFeeBufferBps);

    /// @notice Emitted when a token is added/removed from supported list
    event TokenSupportUpdated(address indexed token, bool supported);

    /// @notice Emitted when preferred token is updated (address(0) means cleared)
    event PreferredTokenSet(address indexed token);

    /// @notice Emitted when a token's oracle feed ID is updated
    event TokenFeedIdSet(address indexed token, bytes32 feedId);

    // -------------------- Admin --------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the purchase vault
    /// @param _defaultAdmin Default admin address
    /// @param _contractAdmin Contract admin address
    /// @param _operator Operator address
    /// @param _gildiPriceOracle Price oracle contract address
    /// @param _paymentAggregator Payment aggregator contract address
    function initialize(
        address _defaultAdmin,
        address _contractAdmin,
        address _operator,
        IGildiPriceOracle _gildiPriceOracle,
        IGildiExchangePaymentAggregator _paymentAggregator
    ) public initializer {
        if (
            _defaultAdmin == address(0) ||
            _contractAdmin == address(0) ||
            _operator == address(0) ||
            address(_gildiPriceOracle) == address(0) ||
            address(_paymentAggregator) == address(0)
        ) {
            revert BadParams();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(ADMIN_ROLE, _contractAdmin);
        _grantRole(OPERATOR_ROLE, _operator);

        gildiPriceOracle = _gildiPriceOracle;
        paymentAggregator = _paymentAggregator;
        emit PriceOracleSet(address(_gildiPriceOracle));
        emit PaymentAggregatorSet(address(_paymentAggregator));

        // Set default slippage buffer to 1% (100 BPS)
        slippageAndFeeBuffer = 100;
    }

    function setPriceOracle(IGildiPriceOracle _gildiPriceOracle) external onlyRole(ADMIN_ROLE) {
        if (address(_gildiPriceOracle) == address(0)) {
            revert BadParams();
        }
        gildiPriceOracle = _gildiPriceOracle;
        emit PriceOracleSet(address(_gildiPriceOracle));
    }

    /// @notice Gets the current slippage and fee buffer
    /// @return bufferBps Current buffer in basis points
    function getSlippageAndFeeBuffer() external view returns (uint256 bufferBps) {
        return slippageAndFeeBuffer;
    }

    /// @notice Sets the slippage and fee buffer
    /// @param _slippageAndFeeBufferBps New buffer in basis points (100 = 1%)
    function setSlippageAndFeeBuffer(uint256 _slippageAndFeeBufferBps) external onlyRole(ADMIN_ROLE) {
        if (_slippageAndFeeBufferBps > 2000) {
            revert BadParams(); // Max 20%
        }
        slippageAndFeeBuffer = _slippageAndFeeBufferBps;
        emit SlippageAndFeeBufferSet(_slippageAndFeeBufferBps);
    }

    /// @notice Sets the payment aggregator
    /// @param _paymentAggregator Payment aggregator contract address
    function setPaymentAggregator(IGildiExchangePaymentAggregator _paymentAggregator) external onlyRole(ADMIN_ROLE) {
        if (address(_paymentAggregator) == address(0)) {
            revert BadParams();
        }
        paymentAggregator = _paymentAggregator;
        emit PaymentAggregatorSet(address(_paymentAggregator));
    }

    /// @notice Adds a token with oracle feed ID (enables support + sets feed ID)
    /// @param _token Token address
    /// @param _feedId Oracle feed ID for the token
    /// @param _setAsPreferred Whether to set this as the preferred token
    function addToken(address _token, bytes32 _feedId, bool _setAsPreferred) external onlyRole(ADMIN_ROLE) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        if (_feedId == bytes32(0)) {
            revert BadParams();
        }

        if (!supportedTokens.contains(_token)) {
            supportedTokens.add(_token);

            tokenFeedIds[_token] = _feedId;

            if (_setAsPreferred) {
                preferredToken = _token;
                emit PreferredTokenSet(_token);
            }

            emit TokenSupportUpdated(_token, true);
            emit TokenFeedIdSet(_token, _feedId);
        }
    }

    /// @notice Removes a token (disables support + clears feed ID)
    /// @param _token Token address to remove
    function removeToken(address _token) external onlyRole(ADMIN_ROLE) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }

        if (supportedTokens.contains(_token)) {
            // Clear preferred token if this was the preferred token
            if (preferredToken == _token) {
                preferredToken = address(0);
                emit PreferredTokenSet(address(0));
            }

            supportedTokens.remove(_token);
            tokenFeedIds[_token] = bytes32(0);

            emit TokenSupportUpdated(_token, false);
            emit TokenFeedIdSet(_token, bytes32(0));
        }
    }

    /// @notice Updates the oracle feed ID for an already supported token
    /// @param _token Token address
    /// @param _feedId New oracle feed ID
    function setTokenFeedId(address _token, bytes32 _feedId) external onlyRole(ADMIN_ROLE) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        if (!supportedTokens.contains(_token)) {
            revert TokenNotSupported(_token);
        }
        if (_feedId == bytes32(0)) {
            revert BadParams();
        }
        tokenFeedIds[_token] = _feedId;
        emit TokenFeedIdSet(_token, _feedId);
    }

    /// @notice Sets the preferred token for intent execution
    /// @param _token Preferred token address (must be configured)
    function setPreferredToken(address _token) external onlyRole(ADMIN_ROLE) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        if (!supportedTokens.contains(_token)) {
            revert TokenNotSupported(_token);
        }
        preferredToken = _token;
        emit PreferredTokenSet(_token);
    }

    /// @notice Clears the preferred token override
    function clearPreferredToken() external onlyRole(ADMIN_ROLE) {
        preferredToken = address(0);
        emit PreferredTokenSet(address(0));
    }

    // -------------------- Lifecycle --------------------

    /// @notice Backend creates an intent bound to the wallet (beneficiary)
    /// @param _intentId Unique identifier for the intent
    /// @param _valueUsd USD value in cents (2 decimals)
    /// @param _beneficiary Who can execute this intent
    /// @param _expiresAt Unix timestamp when intent expires
    function createIntent(
        bytes32 _intentId,
        uint256 _valueUsd,
        address _beneficiary,
        uint256 _expiresAt
    ) external onlyRole(OPERATOR_ROLE) {
        if (_intentId == bytes32(0) || _beneficiary == address(0) || _valueUsd == 0 || _expiresAt == 0) {
            revert BadParams();
        }
        if (_expiresAt <= block.timestamp) {
            revert BadParams();
        }
        if (intents[_intentId].intentId != bytes32(0)) {
            revert IntentAlreadyExists(_intentId);
        }

        intents[_intentId] = PurchaseIntent({
            intentId: _intentId,
            beneficiary: _beneficiary,
            valueUsd: _valueUsd,
            settledUsd: 0,
            debitedToken: address(0),
            debitedTokenPrice: 0,
            debitedTokenAmount: 0,
            expiresAt: _expiresAt,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            status: PurchaseStatus.PENDING,
            executedAtBlock: 0
        });

        emit IntentCreated(_intentId, _beneficiary, _valueUsd, _expiresAt);
    }

    /// @inheritdoc IGildiExchangePurchaseVault
    function executeIntent(
        bytes32 _intentId,
        address _tokenHint,
        IGildiExchangePurchaseVault.ExecutionContext calldata _ctx
    ) external override nonReentrant returns (address token, uint256 tokenAmount) {
        PurchaseIntent storage intent = intents[_intentId];

        // Validation checks
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        if (msg.sender != intent.beneficiary) {
            revert NotBeneficiary(_intentId);
        }
        if (_derivedExpired(intent)) {
            revert IntentExpired(_intentId);
        }
        if (intent.status != PurchaseStatus.PENDING) {
            revert IntentWrongState(_intentId);
        }

        // Token selection business logic using optimal selection
        address selectedToken = _selectToken(_tokenHint, intent.valueUsd, _ctx.releaseId, _ctx.amount, _ctx.buyer);

        // Get current price with validation
        uint256 tokenPriceUsd18 = _getTokenPriceUsd(selectedToken);

        // Calculate token amount needed with slippage buffer
        uint256 requiredTokenAmount = _calculateTokenAmountWithBuffer(selectedToken, intent.valueUsd);

        // Check vault balance
        uint256 vaultBalance = IERC20(selectedToken).balanceOf(address(this));
        if (vaultBalance < requiredTokenAmount) {
            revert InsufficientVaultBalance(selectedToken, requiredTokenAmount, vaultBalance);
        }

        // Transfer tokens; enforce non-FOT by verifying recipient received exact amount
        uint256 recipientBefore = IERC20(selectedToken).balanceOf(msg.sender);
        IERC20(selectedToken).safeTransfer(msg.sender, requiredTokenAmount);
        uint256 recipientAfter = IERC20(selectedToken).balanceOf(msg.sender);
        if (recipientAfter - recipientBefore != requiredTokenAmount) {
            revert FeeOnTransferNotSupported(selectedToken);
        }
        uint256 actualSent = requiredTokenAmount;

        // Update intent state
        intent.debitedToken = selectedToken;
        intent.debitedTokenAmount = actualSent;
        intent.debitedTokenPrice = tokenPriceUsd18;
        intent.executedAtBlock = block.number; // Track execution block
        intent.status = PurchaseStatus.FUNDED; // Mark as funded
        intent.updatedAt = block.timestamp;

        emit IntentExecuted(_intentId, selectedToken, actualSent, intent.valueUsd, tokenPriceUsd18);

        return (selectedToken, actualSent);
    }

    /// @inheritdoc IGildiExchangePurchaseVault
    function settleIntent(
        bytes32 _intentId,
        uint256 _actualUsdSpentCents,
        address _refundToken,
        uint256 _refundTokenAmount
    ) external override nonReentrant {
        PurchaseIntent storage intent = intents[_intentId];

        // Validation checks
        if (intent.intentId == bytes32(0)) revert IntentDoesNotExist(_intentId);
        if (msg.sender != intent.beneficiary) revert NotBeneficiary(_intentId);
        if (intent.status != PurchaseStatus.FUNDED) revert IntentWrongState(_intentId);
        // Allow no-refund path (both zero). If refunding, token must match debited token.
        if (_refundToken == address(0)) {
            if (_refundTokenAmount != 0) {
                revert NotAllowedToken(_refundToken);
            }
        } else {
            if (_refundToken != intent.debitedToken) {
                revert NotAllowedToken(_refundToken);
            }
        }

        // Enforce same-transaction requirement
        if (intent.executedAtBlock != block.number) {
            revert RefundNotSameTransaction(_intentId);
        }

        // Handle token refunds if provided
        if (_refundToken != address(0) && _refundTokenAmount > 0) {
            // Calculate the USD delta that needs to be covered by refund
            uint256 intentValueCents = intent.valueUsd;
            uint256 deltaUsdCents = 0;

            if (intentValueCents > _actualUsdSpentCents) {
                deltaUsdCents = intentValueCents - _actualUsdSpentCents;
            }

            // If there's a delta, validate refund covers it
            if (deltaUsdCents > 0) {
                // Use the same token price from when intent was executed (18 decimals)
                uint256 refundTokenPriceUsd18 = intent.debitedTokenPrice;

                // Measure actual tokens received (ban fee-on-transfer: must match requested)
                uint256 balBefore = IERC20(_refundToken).balanceOf(address(this));
                IERC20(_refundToken).safeTransferFrom(msg.sender, address(this), _refundTokenAmount);
                uint256 balAfter = IERC20(_refundToken).balanceOf(address(this));
                uint256 actualReceived = balAfter - balBefore;
                if (actualReceived != _refundTokenAmount) {
                    revert FeeOnTransferNotSupported(_refundToken);
                }

                // Get token decimals and calculate refund value in cents using FLOOR rounding
                uint8 tokenDecimals = IERC20Metadata(_refundToken).decimals();
                uint256 refundValueCents = Math.mulDiv(
                    actualReceived,
                    refundTokenPriceUsd18,
                    (10 ** tokenDecimals) * 1e16,
                    Math.Rounding.Floor
                );

                // Validate refund covers the delta (reverts entire tx including transfer if insufficient)
                if (refundValueCents < deltaUsdCents) {
                    revert InsufficientRefund(_intentId);
                }
            } else {
                // No delta; still pull tokens if provided to avoid dangling approvals
                IERC20(_refundToken).safeTransferFrom(msg.sender, address(this), _refundTokenAmount);
            }
        }

        // Update intent with settled amount (already in cents) - clamp to intent value
        intent.settledUsd = Math.min(_actualUsdSpentCents, intent.valueUsd);
        intent.status = PurchaseStatus.SETTLED;
        intent.updatedAt = block.timestamp;

        emit IntentSettled(_intentId, intent.settledUsd);
    }

    /// @notice Backend cancels a pending/expired intent. No token movement here.
    /// @param _intentId The intent to cancel
    /// @param _reasonCode Reason for cancellation (for logging)
    function cancelIntent(bytes32 _intentId, uint8 _reasonCode) external onlyRole(OPERATOR_ROLE) {
        PurchaseIntent storage intent = intents[_intentId];
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        // Only pending intents can be cancelled (includes time-expired which are still stored as PENDING)
        if (intent.status != PurchaseStatus.PENDING) {
            revert IntentWrongState(_intentId);
        }

        intent.status = PurchaseStatus.CANCELLED;
        intent.updatedAt = block.timestamp;
        emit IntentCancelled(_intentId, _reasonCode);
    }

    // -------------------- Views --------------------

    /// @notice Gets complete intent details
    /// @param _intentId The intent to query
    /// @return intent The purchase intent with derived status
    function getIntent(bytes32 _intentId) external view returns (PurchaseIntent memory intent) {
        intent = intents[_intentId];
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        if (_derivedExpired(intent) && intent.status == PurchaseStatus.PENDING) {
            intent.status = PurchaseStatus.EXPIRED; // derived, not stored
        }
    }

    /// @notice Gets the status of an intent
    /// @param _intentId The intent to query
    /// @return status The current intent status
    function statusOf(bytes32 _intentId) external view returns (PurchaseStatus status) {
        PurchaseIntent storage intent = intents[_intentId];
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        if (_derivedExpired(intent) && intent.status == PurchaseStatus.PENDING) {
            return PurchaseStatus.EXPIRED;
        }
        return intent.status;
    }

    /// @notice Checks if an intent is expired
    /// @param _intentId The intent to check
    /// @return expired True if the intent is expired
    function isExpired(bytes32 _intentId) external view returns (bool expired) {
        PurchaseIntent storage intent = intents[_intentId];
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        return _derivedExpired(intent) && intent.status == PurchaseStatus.PENDING;
    }

    /// @inheritdoc IGildiExchangePurchaseVault
    function remainingUsd(bytes32 _intentId) external view override returns (uint256 remaining) {
        PurchaseIntent storage intent = intents[_intentId];
        if (intent.intentId == bytes32(0)) {
            revert IntentDoesNotExist(_intentId);
        }
        return _remainingUsd(intent);
    }

    // -------------------- Vault Ops (liquidity) --------------------

    /// @notice Adds tokens to the vault for liquidity
    /// @param _token Token address
    /// @param _amount Amount to add
    function topUp(address _token, uint256 _amount) external nonReentrant {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        if (!supportedTokens.contains(_token)) {
            revert TokenNotSupported(_token);
        }
        uint256 beforeBal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 afterBal = IERC20(_token).balanceOf(address(this));
        if (afterBal - beforeBal != _amount) {
            revert FeeOnTransferNotSupported(_token);
        }
        emit VaultToppedUp(_token, _amount, msg.sender);
    }

    /// @notice Withdraws tokens from the vault
    /// @param _token Token address
    /// @param _amount Amount to withdraw
    /// @param _to Recipient address (address(0) defaults to msg.sender)
    function withdraw(address _token, uint256 _amount, address _to) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        address recipient = _to == address(0) ? msg.sender : _to;
        IERC20(_token).safeTransfer(recipient, _amount);
        emit VaultWithdrawn(_token, _amount, recipient);
    }

    /// @notice Withdraws all tokens of a type from the vault
    /// @param _token Token address
    /// @param _to Recipient address (address(0) defaults to msg.sender)
    function withdrawAll(address _token, address _to) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        address recipient = _to == address(0) ? msg.sender : _to;
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount == 0) {
            return;
        }

        IERC20(_token).safeTransfer(recipient, amount);

        emit VaultWithdrawn(_token, amount, recipient);
    }

    /// @notice Gets vault balance for a token
    /// @param _token Token address
    /// @return balance The vault balance
    function getVaultBalance(address _token) external view returns (uint256 balance) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        return IERC20(_token).balanceOf(address(this));
    }

    /// @notice Gets the oracle feed ID for a token
    /// @param _token Token address
    /// @return feedId The oracle feed ID
    function getTokenFeedId(address _token) external view returns (bytes32 feedId) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        return tokenFeedIds[_token];
    }

    /// @notice Checks if a token is supported for vault operations
    /// @param _token Token address
    /// @return supported True if token is supported
    function isTokenSupported(address _token) external view returns (bool supported) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        return supportedTokens.contains(_token);
    }

    /// @notice Gets all supported tokens
    /// @return tokens Array of supported token addresses
    function getSupportedTokens() external view returns (address[] memory tokens) {
        uint256 length = supportedTokens.length();
        tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = supportedTokens.at(i);
        }
    }

    /// @notice Checks if a token is fully configured (supported + has feed ID)
    /// @param _token Token address
    /// @return configured True if token is supported and has feed ID set
    function isTokenConfigured(address _token) external view returns (bool configured) {
        if (_token == address(0)) {
            revert ZeroAddressToken();
        }
        return supportedTokens.contains(_token) && tokenFeedIds[_token] != bytes32(0);
    }

    /// @notice Checks if vault can fund a purchase with current token balances
    /// @param _intentValueUsdCents Intent value in USD cents
    /// @param _releaseId Release ID for purchase estimation
    /// @param _amount Amount of tokens to purchase
    /// @param _buyer Buyer address for estimation
    /// @return canFund True if purchase can be funded
    /// @return bestToken Address of the most cost-effective token (zero if can't fund)
    /// @return estimatedCost Estimated cost in best token (zero if can't fund)
    /// @inheritdoc IGildiExchangePurchaseVault
    function canFundPurchase(
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) external view override returns (bool canFund, address bestToken, uint256 estimatedCost) {
        address optimalToken = address(0);
        uint256 lowestCostDeviation = type(uint256).max;
        uint256 bestEstimatedCost = 0;

        uint256 tokenCount = supportedTokens.length();
        for (uint256 i = 0; i < tokenCount; i++) {
            address candidateToken = supportedTokens.at(i);

            if (_isTokenViableForIntent(candidateToken, _intentValueUsdCents, _releaseId, _amount, _buyer)) {
                uint256 costDeviation = _calculateCostDeviation(
                    candidateToken,
                    _intentValueUsdCents,
                    _releaseId,
                    _amount,
                    _buyer
                );

                if (costDeviation < lowestCostDeviation) {
                    lowestCostDeviation = costDeviation;
                    optimalToken = candidateToken;

                    // Get estimated cost for this token
                    try paymentAggregator.estimatePurchase(_releaseId, _amount, _buyer, candidateToken) returns (
                        uint256 sourceNeeded,
                        address,
                        IGildiExchangeSwapAdapter.QuoteRoute memory,
                        uint256
                    ) {
                        bestEstimatedCost = sourceNeeded;
                    } catch {
                        // If estimation fails, calculate based on price oracle
                        bestEstimatedCost = _calculateTokenAmountWithBuffer(candidateToken, _intentValueUsdCents);
                    }
                }
            }
        }

        return (optimalToken != address(0), optimalToken, bestEstimatedCost);
    }

    /// @notice Gets the list of supported tokens
    /// @return tokens Array of supported tokens
    function listTokens() external view returns (TokenView[] memory tokens) {
        address[] memory allTokens = supportedTokens.values();
        tokens = new TokenView[](allTokens.length);
        for (uint256 i = 0; i < allTokens.length; i++) {
            address token = allTokens[i];
            tokens[i] = TokenView({token: token, feedId: tokenFeedIds[token], defaultToken: token == preferredToken});
        }
    }

    // -------------------- Internal --------------------

    /// @dev Selects the optimal token for intent execution based on cost analysis
    /// @param _tokenHint Optional token preference from beneficiary
    /// @param _intentValueUsdCents Intent value in USD cents for cost calculation
    /// @param _releaseId Release ID for purchase estimation
    /// @param _amount Amount of tokens to purchase
    /// @param _buyer Buyer address for estimation
    /// @return selectedToken The token address to use
    function _selectToken(
        address _tokenHint,
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) internal view returns (address selectedToken) {
        // If hint is provided and viable, use it
        if (
            _tokenHint != address(0) &&
            _isTokenViableForIntent(_tokenHint, _intentValueUsdCents, _releaseId, _amount, _buyer)
        ) {
            return _tokenHint;
        }

        // Prefer preferred token if configured and viable
        if (
            preferredToken != address(0) &&
            _isTokenViableForIntent(preferredToken, _intentValueUsdCents, _releaseId, _amount, _buyer)
        ) {
            return preferredToken;
        }

        // Otherwise, find the most cost-effective option
        address optimalToken = _findOptimalToken(_intentValueUsdCents, _releaseId, _amount, _buyer);
        if (optimalToken == address(0)) {
            revert NoViableTokenFound(_intentValueUsdCents);
        }
        return optimalToken;
    }

    /// @dev Checks if a token is viable for the intent (sufficient balance + cost analysis)
    function _isTokenViableForIntent(
        address _token,
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) internal view returns (bool viable) {
        if (!supportedTokens.contains(_token)) {
            return false;
        }

        // Calculate required amount with slippage buffer
        uint256 requiredAmountWithBuffer = _calculateTokenAmountWithBuffer(_token, _intentValueUsdCents);

        // Check vault balance
        if (IERC20(_token).balanceOf(address(this)) < requiredAmountWithBuffer) {
            return false;
        }

        // If we have aggregator, do cost analysis
        if (address(paymentAggregator) != address(0)) {
            try paymentAggregator.estimatePurchase(_releaseId, _amount, _buyer, _token) returns (
                uint256 sourceNeeded,
                address,
                IGildiExchangeSwapAdapter.QuoteRoute memory,
                uint256
            ) {
                return sourceNeeded <= requiredAmountWithBuffer;
            } catch {
                return false;
            }
        }

        return true;
    }

    /// @dev Finds the most cost-effective token from all supported options
    function _findOptimalToken(
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) internal view returns (address bestToken) {
        uint256 tokenCount = supportedTokens.length();
        if (tokenCount == 0) {
            return address(0);
        }

        uint256 lowestDeviationBps = type(uint256).max;
        address candidateToken;

        for (uint256 i = 0; i < tokenCount; i++) {
            candidateToken = supportedTokens.at(i);

            if (_isTokenViableForIntent(candidateToken, _intentValueUsdCents, _releaseId, _amount, _buyer)) {
                uint256 deviationBps = _calculateCostDeviation(
                    candidateToken,
                    _intentValueUsdCents,
                    _releaseId,
                    _amount,
                    _buyer
                );

                if (deviationBps < lowestDeviationBps) {
                    lowestDeviationBps = deviationBps;
                    bestToken = candidateToken;
                }
            }
        }

        return bestToken;
    }

    /// @dev Calculates cost deviation for a token compared to intent value
    function _calculateCostDeviation(
        address _token,
        uint256 _intentValueUsdCents,
        uint256 _releaseId,
        uint256 _amount,
        address _buyer
    ) internal view returns (uint256 deviationBps) {
        if (address(paymentAggregator) == address(0)) {
            return 0;
        }

        try paymentAggregator.estimatePurchase(_releaseId, _amount, _buyer, _token) returns (
            uint256 sourceNeeded,
            address releaseCurrency,
            IGildiExchangeSwapAdapter.QuoteRoute memory quoteRoute,
            uint256
        ) {
            // Direct payment (no swap) = 0 deviation
            if (releaseCurrency == _token) {
                return 0;
            }

            // Calculate intent value in token with slippage buffer
            uint256 intentValueInTokenWithBuffer = _calculateTokenAmountWithBuffer(_token, _intentValueUsdCents);

            // Get actual swap input amount from quote
            uint256 actualSwapAmount = quoteRoute.amounts.length > 0 ? quoteRoute.amounts[0] : sourceNeeded;

            // Calculate deviation in BPS
            if (actualSwapAmount > intentValueInTokenWithBuffer) {
                return ((actualSwapAmount - intentValueInTokenWithBuffer) * 10000) / intentValueInTokenWithBuffer;
            } else {
                return ((intentValueInTokenWithBuffer - actualSwapAmount) * 10000) / intentValueInTokenWithBuffer;
            }
        } catch {
            return type(uint256).max; // Max penalty for estimation failure
        }
    }

    /// @dev Calculates token amount needed including slippage buffer
    function _calculateTokenAmountWithBuffer(
        address _token,
        uint256 _intentValueUsdCents
    ) internal view returns (uint256) {
        uint256 price18 = _getTokenPriceUsd(_token);

        uint8 dec = IERC20Metadata(_token).decimals();

        // base = ceil( cents * 10^dec * 1e16 / price )
        uint256 base = Math.mulDiv(_intentValueUsdCents, (10 ** dec) * 1e16, price18, Math.Rounding.Ceil);

        // apply buffer with ceil
        return Math.mulDiv(base, 10000 + slippageAndFeeBuffer, 10000, Math.Rounding.Ceil);
    }

    /// @dev Gets current USD price for a token with validation
    /// @param _token Token address to get price for
    /// @return priceUsd18 Price in USD with 18 decimals
    function _getTokenPriceUsd(address _token) internal view returns (uint256 priceUsd18) {
        if (!supportedTokens.contains(_token)) {
            revert TokenNotSupported(_token);
        }

        bytes32 feedId = tokenFeedIds[_token];
        if (feedId == bytes32(0)) {
            revert TokenFeedIdNotSet(_token);
        }

        IGildiPriceResolver.PriceData memory priceData = gildiPriceOracle.getPriceNoOlderThan(
            feedId,
            300 // 5 minutes max age
        );

        // Normalize price to 18 decimals
        if (priceData.decimals == 18) {
            return priceData.price;
        } else if (priceData.decimals < 18) {
            return priceData.price * (10 ** (18 - priceData.decimals));
        } else {
            return priceData.price / (10 ** (priceData.decimals - 18));
        }
    }

    /// @dev Computes remaining USD cents available for an intent.
    function _remainingUsd(PurchaseIntent memory _intent) internal pure returns (uint256) {
        return _intent.valueUsd - _intent.settledUsd;
    }

    /// @dev Returns true if the current timestamp is past the intent's expiry.
    function _derivedExpired(PurchaseIntent memory _intent) internal view returns (bool) {
        return block.timestamp > _intent.expiresAt;
    }

    /// @dev Converts USD cents to 18-decimal fixed-point amount.
    function _valueUsdCentsToE18(uint256 _valueUsdCents) internal pure returns (uint256) {
        return (_valueUsdCents * 1e18) / 1e2;
    }

    // -------------------- Fallbacks --------------------
    /// @dev Rejects direct ETH transfers to force proper vault management
    receive() external payable {
        revert EthNotAcceptedHere();
    }

    /// @dev Rejects calls to non-existent functions
    fallback() external payable {
        revert EthNotAcceptedHere();
    }
}
