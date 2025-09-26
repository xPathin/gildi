// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IGildiExchange} from '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import {IGildiExchangePaymentProcessor} from '../../interfaces/marketplace/exchange/IGildiExchangePaymentProcessor.sol';
import {IGildiPriceResolver} from '../../interfaces/oracles/price/IGildiPriceOracle.sol';
import {IGildiExchangePaymentAggregator} from '../../interfaces/marketplace/exchange/IGildiExchangePaymentAggregator.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Burnable} from '../../interfaces/token/IERC20Burnable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {SharedErrors} from '../../libraries/marketplace/exchange/SharedErrors.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableMap.sol';

/// @title Gildi Exchange Payment Processor
/// @notice Handles payment processing, fee calculation, and currency conversions for the Gildi Exchange
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiExchangePaymentProcessor is Initializable, IGildiExchangePaymentProcessor {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToBytes32Map;

    // ========== Constants ==========
    /// @dev Dead address for burning tokens
    address private constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    /// @dev Default slippage tolerance in basis points (1%)
    uint16 private constant DEFAULT_SLIPPAGE_BPS = 100;

    // ========== Storage Variables ==========
    /// @notice The GildiExchange contract that calls this contract
    IGildiExchange public gildiExchange;

    /// @dev Mapping from currency address to price feed ID
    EnumerableMap.AddressToBytes32Map private priceFeedIds;

    // ========== Events ==========
    /// @notice Emitted when a price feed is set
    /// @param currency The currency address
    /// @param feedId The price feed ID
    event PriceFeedSet(address indexed currency, bytes32 feedId);

    /// @notice Emitted when a price feed is removed
    /// @param currency The currency address
    event PriceFeedRemoved(address indexed currency);

    /// @notice Emitted when a payment is processed for a listing purchase or fee transfer
    /// @param listingId The ID of the listing being purchased
    /// @param from The address sending the payment
    /// @param to The address receiving the payment
    /// @param sourceToken The source token used for payment
    /// @param amount The amount of source token
    /// @param payoutToken The token received by the recipient (may differ from sourceToken if swapped)
    /// @param swapAmount The amount received after swap (if performed)
    /// @param isFee Whether this payment is a fee transfer
    /// @param swapRequested Whether a token swap was requested
    /// @param swapSuccessful Whether the swap was successful (if requested)
    /// @param slippageBps The slippage tolerance in basis points used for swaps
    event PaymentProcessed(
        uint256 indexed listingId,
        address indexed from,
        address indexed to,
        address sourceToken,
        uint256 amount,
        address payoutToken,
        uint256 swapAmount,
        bool isFee,
        bool swapRequested,
        bool swapSuccessful,
        uint16 slippageBps
    );

    // ========== Structs ==========
    struct PriceFeedInfo {
        address currency;
        bytes32 feedId;
    }

    /// @dev Struct for transfer parameters to reduce stack usage
    struct TransferParams {
        uint256 listingId;
        address from;
        address to;
        uint256 amount;
        address amountCurrency;
        address payoutCurrency;
        uint16 slippageBps;
        bool isFee;
    }

    // ========== Modifiers ==========

    /// @notice Ensures that only the GildiExchange contract can call this function
    modifier onlyGildiExchange() {
        if (msg.sender != address(gildiExchange)) {
            revert SharedErrors.InvalidCaller();
        }
        _;
    }

    /// @notice Ensures that only admins can call this function (checks with GildiExchange)
    modifier onlyAdmin() {
        bytes32 adminRole = gildiExchange.getAppEnvironment().adminRole;
        if (!gildiExchange.hasRole(adminRole, msg.sender)) {
            revert SharedErrors.InvalidCaller();
        }
        _;
    }

    // ========== Constructor and Initializer ==========

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _gildiExchange The address of the GildiExchange contract
    function initialize(address _gildiExchange) external initializer {
        gildiExchange = IGildiExchange(_gildiExchange);
    }

    // ========== Price Oracle Functions ==========

    /// @notice Sets a price feed ID for a currency
    /// @param _currency The currency address
    /// @param _feedId The price feed ID
    function setPriceFeedId(address _currency, bytes32 _feedId) external onlyAdmin {
        (, bytes32 priceFeedId) = priceFeedIds.tryGet(_currency);
        if (priceFeedId != _feedId) {
            priceFeedIds.set(_currency, _feedId);
            emit PriceFeedSet(_currency, _feedId);
        }
    }

    /// @notice Removes a price feed for a currency
    /// @param _currency The currency address
    function removePriceFeedId(address _currency) external onlyAdmin {
        if (priceFeedIds.contains(_currency)) {
            priceFeedIds.remove(_currency);
            emit PriceFeedRemoved(_currency);
        }
    }

    /// @inheritdoc IGildiExchangePaymentProcessor
    function getPriceFeedId(address _currency) public view returns (bytes32) {
        (, bytes32 priceFeedId) = priceFeedIds.tryGet(_currency);
        return priceFeedId;
    }

    /// @notice Returns all price feeds
    /// @return priceFeedInfos Array of price feed information
    function getPriceFeeds() public view returns (PriceFeedInfo[] memory priceFeedInfos) {
        address[] memory keys = priceFeedIds.keys();
        priceFeedInfos = new PriceFeedInfo[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            priceFeedInfos[i] = PriceFeedInfo(keys[i], priceFeedIds.get(keys[i]));
        }
    }

    /// @inheritdoc IGildiExchangePaymentProcessor
    function quoteInCurrency(uint256 _priceInUSD, address _currency) external view returns (uint256) {
        IGildiExchange.AppEnvironment memory $ = _getAppEnvironment();
        bytes32 priceFeedId = getPriceFeedId(_currency);
        uint256 priceAskDecimals = $.settings.priceAskDecimals; // Cache storage read

        IGildiPriceResolver.PriceData memory priceData = $.settings.gildiPriceOracle.getPriceNoOlderThan(
            priceFeedId,
            300
        );
        uint8 currencyDecimals = IERC20Metadata(_currency).decimals();
        uint256 quoteScaled;

        // Simplified calculation with ternary operator
        quoteScaled = priceData.decimals >= priceAskDecimals
            ? _priceInUSD * 10 ** (priceData.decimals - priceAskDecimals)
            : _priceInUSD / 10 ** (priceAskDecimals - priceData.decimals);

        return (quoteScaled * 10 ** currencyDecimals) / priceData.price;
    }

    /// @inheritdoc IGildiExchangePaymentProcessor
    function handleProcessPaymentWithFees(
        uint256 _releaseId,
        address _buyer,
        address _seller,
        uint256 _value,
        address _amountCurrency,
        bool _createFund,
        address _operator,
        bool _isProxyOperation,
        uint256 _listingId,
        address _listingPayoutCurrency,
        uint16 _slippageBps
    ) external onlyGildiExchange {
        // Skip self-transfers
        if (_buyer == _seller) return;

        IGildiExchange.AppEnvironment memory $ = _getAppEnvironment();

        // Calculate fees
        uint256 totalFeeAmount;
        IGildiExchange.Receiver[] memory feeReceivers;
        (totalFeeAmount, feeReceivers) = _calculateFees(_releaseId, _value);

        if (_createFund) {
            // Transfer tokens from operator to fund manager in context
            gildiExchange.transferTokenInContext(_operator, address($.settings.fundManager), _value, _amountCurrency);
        }

        // Process fees - either transfer or create funds
        uint256 receiversLength = feeReceivers.length;
        for (uint256 i = 0; i < receiversLength; i++) {
            address receiver = feeReceivers[i].receiverAddress;
            uint256 feeAmount = feeReceivers[i].value;
            address payoutCurrency = feeReceivers[i].payoutCurrency;

            if (feeAmount > 0) {
                if (_createFund) {
                    // Use helper function to create or add to fund
                    _addToFund(
                        _releaseId,
                        receiver,
                        _buyer,
                        _operator,
                        _isProxyOperation,
                        feeAmount,
                        _amountCurrency,
                        payoutCurrency
                    );
                } else {
                    // Direct transfer for regular sales - use default slippage for fee receivers
                    _executeTransfer(
                        TransferParams({
                            listingId: _listingId,
                            from: _operator,
                            to: receiver,
                            amount: feeAmount,
                            amountCurrency: _amountCurrency,
                            payoutCurrency: payoutCurrency,
                            slippageBps: DEFAULT_SLIPPAGE_BPS,
                            isFee: true
                        })
                    );
                }
            }
        }

        // Handle the remaining amount for the receiver
        uint256 remainingAmount = _value - totalFeeAmount;
        if (remainingAmount > 0) {
            if (_createFund) {
                // Use helper function to create or add to fund
                _addToFund(
                    _releaseId,
                    _seller,
                    _buyer,
                    _operator,
                    _isProxyOperation,
                    remainingAmount,
                    _amountCurrency,
                    _listingPayoutCurrency
                );
            } else {
                // Direct transfer for regular sales
                _executeTransfer(
                    TransferParams({
                        listingId: _listingId,
                        from: _operator,
                        to: _seller,
                        amount: remainingAmount,
                        amountCurrency: _amountCurrency,
                        payoutCurrency: _listingPayoutCurrency,
                        slippageBps: _slippageBps,
                        isFee: false
                    })
                );
            }
        }
    }

    /// @dev Calculates fees for a purchase based on global and release-specific fee distributions
    /// @param _releaseId The ID of the release
    /// @param _amount The amount to calculate fees for
    /// @return Total fees amount
    /// @return Array of fee receivers with their respective amounts
    function _calculateFees(
        uint256 _releaseId,
        uint256 _amount
    ) internal view returns (uint256, IGildiExchange.Receiver[] memory) {
        IGildiExchange.AppEnvironment memory env = _getAppEnvironment();

        // Get fees for this release
        IGildiExchange.FeeDistribution[] memory releaseFees = gildiExchange.getReleaseFees(_releaseId);
        uint256 feeDistCount = releaseFees.length;

        // Count total receivers
        uint256 totalReceivers = 0;
        for (uint256 i = 0; i < feeDistCount; i++) {
            totalReceivers += releaseFees[i].subFeeReceivers.length + 1; // +1 for parent
        }

        // Initialize result arrays
        IGildiExchange.Receiver[] memory receivers = new IGildiExchange.Receiver[](totalReceivers);
        uint256 totalFees = 0;
        uint256 receiverIndex = 0;

        // Process each fee distribution
        for (uint256 i = 0; i < feeDistCount; i++) {
            IGildiExchange.FeeDistribution memory dist = releaseFees[i];

            // Calculate parent fee amount
            uint256 parentFee = (_amount * dist.feeReceiver.value) / env.basisPoints;
            uint256 remainingParentFee = parentFee;
            totalFees += parentFee;

            // Calculate & store sub-receiver fees
            uint256 subCount = dist.subFeeReceivers.length;
            uint256 startIndex = receiverIndex + 1; // Skip parent index for now

            for (uint256 j = 0; j < subCount; j++) {
                uint256 subFee = (parentFee * dist.subFeeReceivers[j].value) / env.basisPoints;
                receivers[startIndex + j] = IGildiExchange.Receiver({
                    receiverAddress: dist.subFeeReceivers[j].receiverAddress,
                    value: uint16(subFee),
                    payoutCurrency: dist.subFeeReceivers[j].payoutCurrency
                });
                remainingParentFee -= subFee;
            }

            // Store parent data after calculating all sub-fees
            receivers[receiverIndex] = IGildiExchange.Receiver({
                receiverAddress: dist.feeReceiver.receiverAddress,
                value: uint16(remainingParentFee),
                payoutCurrency: dist.feeReceiver.payoutCurrency
            });

            // Move index for next distribution
            receiverIndex += subCount + 1;
        }

        return (totalFees, receivers);
    }

    /// @dev Adds funds to fund for a participant
    ///      Delegates to the fund manager contract
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    /// @param _buyer The address of the buyer
    /// @param _operator The address of the operator
    /// @param _isProxyOperation Whether this is a proxy operation
    /// @param _amount The amount to add to fund
    /// @param _amountCurrency The currency of the fund amount
    /// @param _payoutCurrency The currency to payout in
    function _addToFund(
        uint256 _releaseId,
        address _fundParticipant,
        address _buyer,
        address _operator,
        bool _isProxyOperation,
        uint256 _amount,
        address _amountCurrency,
        address _payoutCurrency
    ) internal {
        IGildiExchange.AppEnvironment memory env = _getAppEnvironment();

        // Delegate to the fund manager
        env.settings.fundManager.handleAddToFund(
            _releaseId,
            _fundParticipant,
            _buyer,
            _operator,
            _isProxyOperation,
            _amount,
            _amountCurrency,
            _payoutCurrency
        );
    }

    /// @dev Executes a transfer between addresses, potentially with currency conversion
    /// @param _params Transfer parameters struct containing all transfer details
    function _executeTransfer(TransferParams memory _params) internal {
        if (_params.from == address(this)) {
            revert SharedErrors.ParamError();
        }

        IGildiExchange.AppEnvironment memory env = _getAppEnvironment();
        // Try to burn if destination is zero address or dead address
        if (_params.to == address(0) || _params.to == DEAD_ADDRESS) {
            // Check if we need to swap before burning (currencies differ and payout currency specified)
            if (
                _params.payoutCurrency != address(0) &&
                _params.amountCurrency != _params.payoutCurrency &&
                address(env.settings.paymentAggregator) != address(0)
            ) {
                // Need to swap first, then burn the swapped amount
                IERC20 sourceToken = IERC20(_params.amountCurrency);
                gildiExchange.transferTokenInContext(
                    _params.from,
                    address(this),
                    _params.amount,
                    _params.amountCurrency
                );

                // Check if there's a valid swap route
                (bool hasValidRoute, uint256 expectedAmount, ) = env.settings.paymentAggregator.previewSwapOut(
                    _params.amount,
                    _params.amountCurrency,
                    _params.payoutCurrency
                );

                if (hasValidRoute && expectedAmount > 0) {
                    // Approve the payment aggregator to spend the tokens
                    uint256 allowance = sourceToken.allowance(address(this), address(env.settings.paymentAggregator));
                    if (allowance < _params.amount) {
                        sourceToken.forceApprove(address(env.settings.paymentAggregator), type(uint256).max);
                    }

                    // Calculate minimum amount based on slippage
                    uint256 minAmount = (expectedAmount * (env.basisPoints - _params.slippageBps)) / env.basisPoints;

                    // Execute swap to this contract, then try to burn the swapped amount
                    try
                        env.settings.paymentAggregator.swapOut(
                            _params.amount,
                            _params.amountCurrency,
                            _params.payoutCurrency,
                            minAmount,
                            address(this)
                        )
                    returns (uint256 swapAmount) {
                        // Swap successful, now try to burn the swapped amount in payout currency
                        // First, approve the exchange contract to burn the swapped tokens
                        IERC20(_params.payoutCurrency).forceApprove(address(gildiExchange), swapAmount);

                        if (gildiExchange.tryBurnTokenInContext(address(this), swapAmount, _params.payoutCurrency)) {
                            // Burning succeeded, emit event and return
                            emit PaymentProcessed(
                                _params.listingId,
                                _params.from,
                                address(0), // to: burned tokens go to zero address
                                _params.amountCurrency, // sourceToken
                                _params.amount, // amount
                                _params.payoutCurrency, // payoutToken (swapped currency)
                                swapAmount, // swapAmount
                                _params.isFee,
                                true, // swapRequested
                                true, // swapSuccessful
                                _params.slippageBps
                            );
                            return;
                        } else {
                            // Burning failed, send swapped tokens to dead address
                            IERC20(_params.payoutCurrency).safeTransfer(DEAD_ADDRESS, swapAmount);
                            emit PaymentProcessed(
                                _params.listingId,
                                _params.from,
                                DEAD_ADDRESS,
                                _params.amountCurrency, // sourceToken
                                _params.amount, // amount
                                _params.payoutCurrency, // payoutToken (swapped currency)
                                swapAmount, // swapAmount
                                _params.isFee,
                                true, // swapRequested
                                true, // swapSuccessful
                                _params.slippageBps
                            );
                            return;
                        }
                    } catch {
                        // Swap failed, fall through to original burn logic
                    }
                }
                // If no valid route or swap failed, fall through to original burn logic
            }

            // Original burn logic: try to burn in original currency
            if (gildiExchange.tryBurnTokenInContext(_params.from, _params.amount, _params.amountCurrency)) {
                // Burning succeeded, emit event and return
                emit PaymentProcessed(
                    _params.listingId,
                    _params.from,
                    address(0), // to: burned tokens go to zero address
                    _params.amountCurrency, // sourceToken
                    _params.amount, // amount
                    _params.amountCurrency, // payoutToken (same as source for direct burns)
                    _params.amount, // swapAmount (no swap, same amount)
                    _params.isFee,
                    false, // swapRequested (no swap for direct burns)
                    false, // swapSuccessful (no swap for direct burns)
                    0
                );
                return;
            } else {
                // Burning failed, redirect to dead address
                _params.to = DEAD_ADDRESS;
            }
        }

        bool swapRequested = false;
        bool swapSuccessful = false;
        address finalPayoutCurrency = _params.payoutCurrency;
        uint256 finalAmount = _params.amount; // Initialize to original amount, will be updated if swap is successful

        // If amount currency and payout currency are the same or payout currency is not specified or destination is DEAD_ADDRESS, do direct transfer
        if (
            _params.payoutCurrency == address(0) ||
            _params.amountCurrency == _params.payoutCurrency ||
            _params.to == DEAD_ADDRESS ||
            address(env.settings.paymentAggregator) == address(0)
        ) {
            gildiExchange.transferTokenInContext(_params.from, _params.to, _params.amount, _params.amountCurrency);
            // In this case, the payout currency is the same as the amount currency
            finalPayoutCurrency = _params.amountCurrency;
        } else {
            swapRequested = true;

            // First, get the tokens to this contract if they're not already here
            IERC20 sourceToken = IERC20(_params.amountCurrency);
            gildiExchange.transferTokenInContext(_params.from, address(this), _params.amount, _params.amountCurrency);

            // Check if there's a valid swap route
            (bool hasValidRoute, uint256 expectedAmount, ) = env.settings.paymentAggregator.previewSwapOut(
                _params.amount,
                _params.amountCurrency,
                _params.payoutCurrency
            );

            if (hasValidRoute && expectedAmount > 0) {
                // Approve the payment aggregator to spend the tokens
                uint256 allowance = sourceToken.allowance(address(this), address(env.settings.paymentAggregator));
                if (allowance < _params.amount) {
                    sourceToken.forceApprove(address(env.settings.paymentAggregator), type(uint256).max);
                }

                // Calculate minimum amount based on slippage (10000 - slippageBps) / 10000
                uint256 minAmount = (expectedAmount * (env.basisPoints - _params.slippageBps)) / env.basisPoints;

                // Execute the swap
                try
                    env.settings.paymentAggregator.swapOut(
                        _params.amount,
                        _params.amountCurrency,
                        _params.payoutCurrency,
                        minAmount,
                        _params.to
                    )
                returns (uint256 swapAmount) {
                    // Swap successful
                    swapSuccessful = true;
                    finalPayoutCurrency = _params.payoutCurrency;
                    finalAmount = swapAmount;
                } catch {
                    // Swap failed, fallback to direct transfer
                    sourceToken.safeTransfer(_params.to, _params.amount);
                    finalPayoutCurrency = _params.amountCurrency;
                }
            } else {
                // No valid route, fallback to direct transfer
                sourceToken.safeTransfer(_params.to, _params.amount);
                finalPayoutCurrency = _params.amountCurrency;
            }
        }

        // Emit payment processed event
        emit PaymentProcessed(
            _params.listingId,
            _params.from,
            _params.to,
            _params.amountCurrency,
            _params.amount,
            finalPayoutCurrency,
            finalAmount,
            _params.isFee,
            swapRequested,
            swapSuccessful,
            _params.slippageBps
        );
    }

    /// @dev Gets the application environment from the GildiExchange contract
    /// @dev Returns the app environment structure containing all settings and roles
    function _getAppEnvironment() internal view returns (IGildiExchange.AppEnvironment memory) {
        return gildiExchange.getAppEnvironment();
    }

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
