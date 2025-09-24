// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../../interfaces/external/IWNative.sol';
import '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import '../../interfaces/marketplace/exchange/IGildiExchangePaymentAggregator.sol';
import '../../interfaces/marketplace/exchange/IGildiExchangeSwapAdapter.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/// @title GildiExchangePaymentBaseCore
/// @notice Core contract holding shared logic and storage definitions for the purchase flow.
/// This contract is completely agnostic to access control and reentrancy protection;
/// it just provides internal helper functions and defines a storage struct along with internal getters.
/// Derived contracts must implement _getStorage().
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
abstract contract GildiExchangePaymentBaseCore is IGildiExchangePaymentAggregator {
    using SafeERC20 for IERC20;
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    // --- Storage Struct (shared by both implementations) ---
    /// @dev Storage struct for the Gildi Marketplace.
    /// @param gildiExchange The Gildi Exchange contract.
    /// @param marketplaceToken DEPRECATED: The marketplace token address. Use gildiExchange.getActiveMarketplaceReleaseAsset() instead.
    /// @param allowNative If native payments are allowed.
    /// @param wrappedNative The wrapped native token address.
    /// @param adapters The list of aggregator/DEX adapters.
    /// @param allowedPurchaseTokens The allowed purchase tokens.
    /// @param isPurchaseTokenAllowed Mapping of allowed purchase tokens.
    struct GildiExchangePaymentBaseStorage {
        IGildiExchange gildiExchange;
        bool purchaseAllowNative;
        address wrappedNative;
        IGildiExchangeSwapAdapter[] adapters;
        address[] allowedPurchaseTokens;
        mapping(address => bool) isPurchaseTokenAllowed;
    }

    /// @dev Emitted when an index is out of bounds.
    error IndexOutOfRange();

    /// @dev Emitted when there are not enough source tokens for the best route.
    error NotEnoughSourceTokensForBestRoute();

    /// @dev Emitted when slippage exceeds the limit.
    error SlippageExceeded();

    /// @dev Emitted when a token is not allowed for purchase.
    /// @param token The token that is not allowed.
    error PurchaseTokenNotAllowed(address token);

    /// @dev Emitted when native currency is not allowed for purchase.
    error NativeNotAllowed();

    /// @dev Emitted when the msg.value does not match the expected amount.
    error IncorrectMsgValue();

    /// @dev Emitted when there are no swap adapters configured.
    error NoAdapters();

    /// @dev Emitted when no valid route is found for a swap.
    error NoValidRoute();

    /// @dev Emitted when there is insufficient liquidity for a swap.
    error InsufficientLiquidity();

    /// @dev Emitted when the received amount is less than the required minimum.
    error InsufficientReceiveAmount();

    /// @dev Emitted when a swap operation fails.
    error SwapOutFailed();

    /// @notice Emitted when a new swap adapter is added.
    /// @param adapter The adapter that was added.
    event AdapterAdded(IGildiExchangeSwapAdapter adapter);

    /// @notice Emitted when a swap adapter is removed.
    /// @param adapter The adapter that was removed.
    event AdapterRemoved(IGildiExchangeSwapAdapter adapter);

    /// @notice Emitted when a token's swap-in status is changed.
    /// @param token The token address.
    /// @param allowed Whether the token is allowed for swap-in.
    event AllowedSwapInTokenSet(address token, bool allowed);

    /// @notice Emitted when the wrapped native token address is set.
    /// @param wnative The wrapped native token address.
    event WrappedNativeSet(address wnative);

    /// @notice Emitted when the native payment allowance is changed.
    /// @param allow Whether native payments are allowed.
    event PurchaseAllowNativeSet(bool allow);

    /// @notice Emitted when a token's source status is changed.
    /// @param token The token address.
    /// @param allowed Whether the token is allowed as a source.
    event SourceTokenSet(address token, bool allowed);

    /// @notice Emitted when a marketplace token leftover is returned.
    event MarketplaceLeftoverReturned(
        address indexed marketplaceToken,
        address recipient,
        uint256 sourceAmount,
        bool swapped,
        address targetToken,
        uint256 targetAmount
    );

    /// @notice Emitted when a swap operation is executed.
    /// @param sourceToken The address of the source token.
    /// @param targetToken The address of the target token.
    /// @param sourceAmount The amount of source tokens swapped.
    /// @param targetAmount The amount of target tokens received.
    /// @param recipient The address that received the target tokens.
    /// @param adapter The adapter used for the swap.
    /// @param route The detailed routing information used for the swap.
    event SwapExecuted(
        address indexed sourceToken,
        address indexed targetToken,
        uint256 sourceAmount,
        uint256 targetAmount,
        address recipient,
        address adapter,
        IGildiExchangeSwapAdapter.QuoteRoute route
    );

    /// @notice Emitted when a swap route is selected for a transaction.
    /// @param sourceToken The starting token for the swap.
    /// @param targetToken The desired output token.
    /// @param amount The amount to be swapped.
    /// @param expectedOutput The expected output amount.
    /// @param selectedAdapter The address of the selected adapter for the route.
    event SwapRouteSelected(
        address indexed sourceToken,
        address indexed targetToken,
        uint256 amount,
        uint256 expectedOutput,
        address selectedAdapter
    );

    /// @notice The best adapter quote for a swap out
    /// @param bestAdapter The best adapter
    /// @param bestTargetAmount The best target amount
    /// @param bestQuoteData The best quote data
    /// @param bestQuoteRoute The best quote route
    /// @param hasValidRoute Whether there is any valid route.
    struct BestAdapterSwapOutQuote {
        address bestAdapter;
        uint256 bestTargetAmount;
        bytes bestQuoteData;
        IGildiExchangeSwapAdapter.QuoteRoute bestQuoteRoute;
        bool hasValidRoute;
    }

    // --- Abstract function: must return the storage pointer ---
    function _getStorage() internal view virtual returns (GildiExchangePaymentBaseStorage storage);

    /// @dev Returns the message sender.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual returns (address);

    // --- Internal Setters ---
    function _setPurchaseAllowNative(bool _allow) internal virtual {
        if (_allow == getPurchaseAllowNative()) {
            return;
        }

        _getStorage().purchaseAllowNative = _allow;
        emit PurchaseAllowNativeSet(_allow);
    }

    function _setAllowedPurchaseToken(address _token, bool _allowed) internal virtual {
        GildiExchangePaymentBaseStorage storage $ = _getStorage();
        if (_allowed) {
            if (!$.isPurchaseTokenAllowed[_token]) {
                $.allowedPurchaseTokens.push(_token);
                $.isPurchaseTokenAllowed[_token] = true;
            }
        } else {
            if ($.isPurchaseTokenAllowed[_token]) {
                delete $.isPurchaseTokenAllowed[_token];
                uint256 len = $.allowedPurchaseTokens.length;
                for (uint256 i = 0; i < len; i++) {
                    if (_token == $.allowedPurchaseTokens[i]) {
                        $.allowedPurchaseTokens[i] = $.allowedPurchaseTokens[len - 1];
                        $.allowedPurchaseTokens.pop();
                        break;
                    }
                }
            }
        }
        emit AllowedSwapInTokenSet(_token, _allowed);
    }

    function _addAdapter(IGildiExchangeSwapAdapter _adapter) internal virtual {
        for (uint256 i = 0; i < getAdapters().length; i++) {
            if (address(_adapter) == address(getAdapters()[i])) {
                return;
            }
        }

        GildiExchangePaymentBaseStorage storage $ = _getStorage();
        $.adapters.push(_adapter);
        emit AdapterAdded(_adapter);
    }

    function _setWrappedNative(address _wnative) internal virtual {
        if (_wnative == getWrappedNative()) {
            return;
        }

        _getStorage().wrappedNative = _wnative;
        emit WrappedNativeSet(_wnative);
    }

    function _removeAdapter(uint256 index) internal virtual {
        GildiExchangePaymentBaseStorage storage $ = _getStorage();
        IGildiExchangeSwapAdapter[] storage adapters = $.adapters;
        if (index >= adapters.length) {
            revert IndexOutOfRange();
        }
        emit AdapterRemoved(adapters[index]);
        adapters[index] = adapters[adapters.length - 1];
        adapters.pop();
    }

    function _removeAdapter(IGildiExchangeSwapAdapter _adapter) internal virtual {
        GildiExchangePaymentBaseStorage storage $ = _getStorage();
        uint256 len = $.adapters.length;
        for (uint256 i = 0; i < len; i++) {
            if (address(_adapter) == address($.adapters[i])) {
                emit AdapterRemoved(_adapter);
                if (i != len - 1) {
                    $.adapters[i] = $.adapters[len - 1];
                }
                $.adapters.pop();
                break;
            }
        }
    }

    // --- Internal Logic ---
    function _approveMarketplaceIfNeeded(address _marketplaceToken, uint256 _requiredAmount) internal {
        uint256 allowanceNow = IERC20(_marketplaceToken).allowance(address(this), address(getGildiExchange()));
        if (allowanceNow < _requiredAmount) {
            IERC20(_marketplaceToken).forceApprove(address(getGildiExchange()), type(uint256).max);
        }
    }

    function _collectPurchaseToken(address _sourceToken, uint256 _sourceMaxAmount) internal {
        if (!isPurchaseTokenAllowed(_sourceToken)) {
            revert PurchaseTokenNotAllowed(_sourceToken);
        }
        IERC20(_sourceToken).safeTransferFrom(msg.sender, address(this), _sourceMaxAmount);
    }

    function _approveFundsToAdapter(address _adapter, address _sourceToken, uint256 _amount) internal {
        IERC20(_sourceToken).forceApprove(_adapter, _amount);
    }

    /// @notice Executes a swap out operation, converting source tokens to a target token
    /// @param _amount The amount of source tokens to swap
    /// @param _sourceCurrency The source currency to swap from
    /// @param _targetToken The token to swap to
    /// @param _minTargetAmount The minimum amount of target tokens to receive
    /// @param _recipient The recipient of the target tokens
    /// @return targetReceived The amount of target tokens received
    function _executeSwapOut(
        uint256 _amount,
        address _sourceCurrency,
        address _targetToken,
        uint256 _minTargetAmount,
        address _recipient
    ) internal returns (uint256 targetReceived) {
        // No swap needed if the target token is the source token
        if (_targetToken == _sourceCurrency) {
            IERC20(_sourceCurrency).safeTransfer(_recipient, _amount);
            return _amount;
        }

        // Find the best adapter for the swap
        BestAdapterSwapOutQuote memory quote = _swapOutQuoteAndPickAdapter(_amount, _targetToken, _sourceCurrency);

        if (!quote.hasValidRoute) {
            revert NoValidRoute();
        }

        if (quote.bestTargetAmount == 0) {
            revert InsufficientLiquidity();
        }

        if (quote.bestTargetAmount < _minTargetAmount) {
            revert InsufficientReceiveAmount();
        }

        _approveFundsToAdapter(quote.bestAdapter, _sourceCurrency, _amount);

        // Emit event for selected route before execution
        emit SwapRouteSelected(_sourceCurrency, _targetToken, _amount, quote.bestTargetAmount, quote.bestAdapter);

        // Execute the swap
        targetReceived = IGildiExchangeSwapAdapter(quote.bestAdapter).swapOut(
            _sourceCurrency,
            _targetToken,
            _amount,
            _minTargetAmount,
            _recipient,
            quote.bestQuoteData
        );

        if (targetReceived < _minTargetAmount) {
            revert SwapOutFailed();
        }

        // Emit event for successful swap execution
        emit SwapExecuted(
            _sourceCurrency,
            _targetToken,
            _amount,
            targetReceived,
            _recipient,
            quote.bestAdapter,
            quote.bestQuoteRoute
        );

        return targetReceived;
    }

    function _returnLeftoverPurchaseSource(address _sourceToken, uint256 _amount, bool _isNative) internal {
        if (_isNative) {
            _unwrapNative(_amount);
            Address.sendValue(payable(msg.sender), _amount);
        } else {
            IERC20(_sourceToken).safeTransfer(msg.sender, _amount);
        }
    }

    function _collectAndWrapNative(uint256 _sourceMaxAmount) internal {
        if (!getPurchaseAllowNative() || getWrappedNative() == address(0)) {
            revert NativeNotAllowed();
        }
        if (msg.value != _sourceMaxAmount) {
            revert IncorrectMsgValue();
        }
        IWNative(getWrappedNative()).deposit{value: _sourceMaxAmount}();
    }

    function _unwrapNative(uint256 _amount) internal {
        IWNative(getWrappedNative()).withdraw(_amount);
    }

    /// @dev Must pick the best aggregator adapter among available ones.
    ///      Can be overriden to implement custom logic.
    /// @param _sourceToken The token to swap from.
    /// @param _marketplaceAmount The amount of marketplace tokens needed.
    /// @return bestAdapter The chosen adapter.
    /// @return sourceNeeded The amount of _sourceToken required.
    /// @return quoteData The data to pass to bestAdapter.swapIn(...).
    function _swapInQuoteAndPickAdapter(
        address _sourceToken,
        uint256 _marketplaceAmount,
        uint256 _releaseId
    )
        internal
        view
        virtual
        returns (
            IGildiExchangeSwapAdapter bestAdapter,
            uint256 sourceNeeded,
            bytes memory quoteData,
            IGildiExchangeSwapAdapter.QuoteRoute memory quoteRoute
        )
    {
        IGildiExchangeSwapAdapter[] memory adapters = getAdapters();
        address marketplaceToken = getMarketplaceToken(_releaseId);

        if (adapters.length == 0) {
            revert NoAdapters();
        }

        uint256 bestNeeded = type(uint256).max;
        bytes memory bestData;
        IGildiExchangeSwapAdapter.QuoteRoute memory bestQuoteRoute;
        bool anyValidRouteExists = false;
        bool insufficientLiquidity = false;

        for (uint256 i = 0; i < adapters.length; i++) {
            IGildiExchangeSwapAdapter.SwapInQuote memory quote = adapters[i].quoteSwapIn(
                _sourceToken,
                marketplaceToken,
                _marketplaceAmount
            );

            if (quote.validRoute) {
                anyValidRouteExists = true;

                if (quote.sourceTokenRequired == 0) {
                    // Valid route exists but has insufficient liquidity
                    insufficientLiquidity = true;
                } else if (quote.sourceTokenRequired < bestNeeded) {
                    // Found a better route with sufficient liquidity
                    bestNeeded = quote.sourceTokenRequired;
                    bestAdapter = adapters[i];
                    bestData = quote.rawQuoteData;
                    bestQuoteRoute = quote.quoteRoute;
                }
            }
        }

        if (address(bestAdapter) == address(0)) {
            // No adapter found with sufficient liquidity
            if (anyValidRouteExists && insufficientLiquidity) {
                // Valid routes exist but all have insufficient liquidity
                revert InsufficientLiquidity();
            } else {
                // No valid route exists between these tokens
                revert NoValidRoute();
            }
        }
        return (bestAdapter, bestNeeded, bestData, bestQuoteRoute);
    }

    /// @dev Estimates the amount of `_sourceToken` required to get `_amount` of `_targetToken` and returns the current best route.
    /// @param _amount The amount of the target token.
    /// @param _targetToken The target token.
    /// @param _sourceToken The source token.
    /// @return quote The quote.
    function _swapOutQuoteAndPickAdapter(
        uint256 _amount,
        address _targetToken,
        address _sourceToken
    ) internal view virtual returns (BestAdapterSwapOutQuote memory quote) {
        IGildiExchangeSwapAdapter[] memory adapters = getAdapters();

        quote.bestTargetAmount = 0;

        /* uint256 targetTokenOut;
        bytes rawQuoteData;
        QuoteRoute quoteRoute;
        bool validRoute;*/
        for (uint256 i = 0; i < adapters.length; i++) {
            try adapters[i].quoteSwapOut(_sourceToken, _targetToken, _amount) returns (
                IGildiExchangeSwapAdapter.SwapOutQuote memory swapOutQuote
            ) {
                if (swapOutQuote.validRoute) {
                    if (swapOutQuote.targetTokenOut > quote.bestTargetAmount || !quote.hasValidRoute) {
                        // Better route found with non-zero output
                        quote.bestTargetAmount = swapOutQuote.targetTokenOut;
                        quote.bestAdapter = address(adapters[i]);
                        quote.bestQuoteData = swapOutQuote.rawQuoteData;
                        quote.bestQuoteRoute = swapOutQuote.quoteRoute;
                        quote.hasValidRoute = true;
                    }
                }
            } catch {
                // Skip this adapter if it reverts
                continue;
            }
        }
    }

    /// @dev Attempts to refund leftover marketplace tokens by swapping them back to the original source token
    /// @dev Falls back to direct transfer of marketplace token if the swap fails
    /// @param _sourceToken The marketplace token address
    /// @param _amount The amount of marketplace tokens to refund
    /// @param _targetToken The destination token (original source token)
    /// @param _recipient The recipient address who will receive the tokens
    function _refundReleaseMarketplaceToken(
        address _sourceToken,
        uint256 _amount,
        address _targetToken,
        address _recipient
    ) internal {
        IERC20 sourceToken = IERC20(_sourceToken);

        if (_targetToken == _sourceToken) {
            sourceToken.safeTransfer(_recipient, _amount);
            return;
        }

        // Try swap out
        BestAdapterSwapOutQuote memory quote = _swapOutQuoteAndPickAdapter(_amount, _targetToken, _sourceToken);

        bool swapExecuted = false;

        if (quote.hasValidRoute && quote.bestTargetAmount > 0) {
            // Emit event for selected route before execution
            emit SwapRouteSelected(_sourceToken, _targetToken, _amount, quote.bestTargetAmount, quote.bestAdapter);

            _approveFundsToAdapter(quote.bestAdapter, _sourceToken, _amount);
            try
                IGildiExchangeSwapAdapter(quote.bestAdapter).swapOut(
                    _sourceToken,
                    _targetToken,
                    _amount,
                    0,
                    _recipient,
                    quote.bestQuoteData
                )
            returns (uint256 targetReceived) {
                if (targetReceived > 0) {
                    // Emit events for successful swap
                    emit SwapExecuted(
                        _sourceToken,
                        _targetToken,
                        _amount,
                        targetReceived,
                        _recipient,
                        quote.bestAdapter,
                        quote.bestQuoteRoute
                    );
                    swapExecuted = true;
                }
            } catch {
                _approveFundsToAdapter(quote.bestAdapter, _sourceToken, 0);
            }
        }

        if (!swapExecuted) {
            sourceToken.safeTransfer(_recipient, _amount);
            emit MarketplaceLeftoverReturned(_sourceToken, _recipient, _amount, false, address(0), 0);
        }
    }

    // --- Public Functions ---

    // --- Getters ---
    function getGildiExchange() public view returns (IGildiExchange) {
        return _getStorage().gildiExchange;
    }

    /// @notice Returns the active marketplace token address for a given release or the default marketplace token.
    /// @param _releaseId Optional release ID to get the specific token for, or 0 for default
    /// @return The marketplace token address to use for the specified release
    function getMarketplaceToken(uint256 _releaseId) public view returns (address) {
        IGildiExchange exchange = getGildiExchange();
        return exchange.getActiveMarketplaceReleaseAsset(_releaseId);
    }

    function getPurchaseAllowNative() public view returns (bool) {
        return _getStorage().purchaseAllowNative;
    }

    function getWrappedNative() public view returns (address) {
        return _getStorage().wrappedNative;
    }

    function getAdapters() public view returns (IGildiExchangeSwapAdapter[] memory) {
        return _getStorage().adapters;
    }

    function isPurchaseTokenAllowed(address _token) public view returns (bool) {
        return _getStorage().isPurchaseTokenAllowed[_token];
    }

    function getAllowedPurchaseTokens() public view returns (address[] memory) {
        return _getStorage().allowedPurchaseTokens;
    }

    /// @inheritdoc IGildiExchangePaymentAggregator
    function swapOut(
        uint256 _amount,
        address _sourceCurrency,
        address _targetToken,
        uint256 _minTargetAmount,
        address _recipient
    ) public virtual returns (uint256 targetReceived) {
        // First, validate if we have a valid route
        (bool hasValidRoute, uint256 expectedAmount, ) = previewSwapOut(_amount, _sourceCurrency, _targetToken);
        if (!hasValidRoute || expectedAmount < _minTargetAmount) {
            revert NoValidRoute();
        }

        // Transfer source tokens from the sender to this contract
        IERC20(_sourceCurrency).safeTransferFrom(_msgSender(), address(this), _amount);

        // Execute the swap out
        return _executeSwapOut(_amount, _sourceCurrency, _targetToken, _minTargetAmount, _recipient);
    }

    /// @inheritdoc IGildiExchangePaymentAggregator
    function purchase(
        uint256 _releaseId,
        uint256 _amount,
        address _sourceToken,
        uint256 _sourceMaxAmount
    ) public payable returns (uint256 amountUsdSpent) {
        // 1) Get required marketplace token amount.
        (uint256 requiredSourceAmount, address releaseCurrency, ) = getGildiExchange().quotePricePreview(
            _releaseId,
            _amount,
            msg.sender
        );

        // 2) Collect user’s source tokens.
        bool isNative = _sourceToken == address(0);
        if (isNative) {
            _collectAndWrapNative(_sourceMaxAmount);
            _sourceToken = getWrappedNative();
        } else {
            _collectPurchaseToken(_sourceToken, _sourceMaxAmount);
        }

        uint256 sourceSpent = 0;

        if (_sourceToken != releaseCurrency) {
            // 3) Pick the best adapter.
            (
                IGildiExchangeSwapAdapter bestAdapter,
                uint256 sourceNeeded,
                bytes memory quoteData,

            ) = _swapInQuoteAndPickAdapter(_sourceToken, requiredSourceAmount, _releaseId);
            if (sourceNeeded > _sourceMaxAmount) {
                revert NotEnoughSourceTokensForBestRoute();
            }

            // 4) Transfer funds to the adapter.
            _approveFundsToAdapter(address(bestAdapter), _sourceToken, _sourceMaxAmount);

            // 5) Execute the swap.
            sourceSpent = bestAdapter.swapIn(
                _sourceToken,
                releaseCurrency,
                _sourceMaxAmount,
                requiredSourceAmount,
                address(this),
                quoteData
            );
            if (sourceSpent > _sourceMaxAmount) {
                revert SlippageExceeded();
            }
        }

        // 6) Approve and call purchase.
        _approveMarketplaceIfNeeded(releaseCurrency, requiredSourceAmount);
        (uint256 releaseMarketplaceTokenSpent, uint256 actualUsdSpent) = getGildiExchange().purchase(
            _releaseId,
            _amount,
            requiredSourceAmount,
            _msgSender(),
            true
        );
        if (_sourceToken == releaseCurrency) {
            sourceSpent = releaseMarketplaceTokenSpent;
        }

        // 7) Refund leftover tokens.
        if (sourceSpent < _sourceMaxAmount) {
            _returnLeftoverPurchaseSource(_sourceToken, _sourceMaxAmount - sourceSpent, isNative);
        }

        // 8) Try swap back unspent release marketplace token
        if (releaseMarketplaceTokenSpent < requiredSourceAmount && _sourceToken != releaseCurrency) {
            _refundReleaseMarketplaceToken(
                releaseCurrency,
                requiredSourceAmount - releaseMarketplaceTokenSpent,
                _sourceToken,
                msg.sender
            );
        }

        return actualUsdSpent;
    }

    /// @inheritdoc IGildiExchangePaymentAggregator
    function estimatePurchase(
        uint256 _releaseId,
        uint256 _amount,
        address _buyer,
        address _sourceToken
    )
        public
        view
        virtual
        returns (
            uint256 sourceNeeded,
            address releaseCurrency,
            IGildiExchangeSwapAdapter.QuoteRoute memory quoteRoute,
            uint256 totalPriceUsd
        )
    {
        if (_sourceToken == address(0)) {
            _sourceToken = getWrappedNative();
        }

        IGildiExchange gildiExchange = getGildiExchange();
        (uint256 requiredAmount, address requiredAmountCurrency, uint256 usdPrice) = gildiExchange.quotePricePreview(
            _releaseId,
            _amount,
            _buyer
        );

        if (_sourceToken == requiredAmountCurrency) {
            return (
                requiredAmount,
                requiredAmountCurrency,
                IGildiExchangeSwapAdapter.QuoteRoute({
                    marketplaceAdapter: address(0),
                    route: new address[](0),
                    fees: new uint128[](0),
                    amounts: new uint128[](0),
                    virtualAmountsWithoutSlippage: new uint128[](0)
                }),
                usdPrice
            );
        }

        (, sourceNeeded, , quoteRoute) = _swapInQuoteAndPickAdapter(_sourceToken, requiredAmount, _releaseId);

        return (sourceNeeded, requiredAmountCurrency, quoteRoute, usdPrice);
    }

    /// @notice Previews a swap out operation to check if there's a valid route and estimate the output amount.
    /// @param _amount The amount of source tokens to swap.
    /// @param _sourceCurrency The address of the source token.
    /// @param _targetToken The token to swap to.
    /// @return hasValidRoute Whether there's a valid route for the swap.
    /// @return expectedTargetAmount The expected amount of target tokens to receive.
    /// @return bestRoute The best route for the swap.
    function previewSwapOut(
        uint256 _amount,
        address _sourceCurrency,
        address _targetToken
    )
        public
        view
        virtual
        returns (
            bool hasValidRoute,
            uint256 expectedTargetAmount,
            IGildiExchangeSwapAdapter.QuoteRoute memory bestRoute
        )
    {
        // No swap needed if the target token is the source token
        if (_targetToken == _sourceCurrency) {
            return (
                false,
                _amount,
                IGildiExchangeSwapAdapter.QuoteRoute({
                    marketplaceAdapter: address(0),
                    route: new address[](0),
                    fees: new uint128[](0),
                    amounts: new uint128[](0),
                    virtualAmountsWithoutSlippage: new uint128[](0)
                })
            );
        }

        // Check for adapters
        IGildiExchangeSwapAdapter[] memory adapters = getAdapters();
        if (adapters.length == 0) {
            return (
                false,
                0,
                IGildiExchangeSwapAdapter.QuoteRoute({
                    marketplaceAdapter: address(0),
                    route: new address[](0),
                    fees: new uint128[](0),
                    amounts: new uint128[](0),
                    virtualAmountsWithoutSlippage: new uint128[](0)
                })
            );
        }

        BestAdapterSwapOutQuote memory quote = _swapOutQuoteAndPickAdapter(_amount, _targetToken, _sourceCurrency);
        expectedTargetAmount = quote.bestTargetAmount;
        bestRoute = quote.bestQuoteRoute;
        hasValidRoute = quote.hasValidRoute;
    }
}
