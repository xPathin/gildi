// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../../../../../interfaces/marketplace/exchange/IGildiExchangeSwapAdapter.sol';
import '../../../../../interfaces/external/uniswap/v3/IUniswapV3SwapRouter02.sol';
import '../../../../../interfaces/external/uniswap/v3/quoter/IUniswapV3ViewQuoter.sol';
import {ContextUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title UniswapV3SwapAdapter
/// @notice An adapter for interfacing with Uniswap V3 liquidity pools
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract UniswapV3SwapAdapter is
    IGildiExchangeSwapAdapter,
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    address public quoter; // Uniswap V3 Quoter address
    address public router; // Uniswap V3 Router address

    /// @dev Emitted when a route has invalid length
    error InvalidRouteLength();
    /// @dev Emitted when the route does not start with the input token
    error RouteMustStartWithTokenIn();
    /// @dev Emitted when the route does not end with the output token
    error RouteMustEndWithTokenOut();
    /// @dev Emitted when an index is out of array bounds
    error IndexOutOfBounds();
    /// @dev Emitted when a maximum amount is exceeded
    error ExceededMaxAmount();
    /// @dev Emitted when the output amount is insufficient
    error InsufficientOutputAmount();
    /// @dev Emitted when no valid route is found
    error NoValidRoute();

    /// @notice Struct to represent a Uniswap V3 route
    /// @dev Combines token path and fees as a single unit
    struct UniswapRoute {
        address[] path; // The tokens in the route
        uint24[] fees; // The fees for each hop (length = path.length - 1)
    }

    /// @dev Stores custom routes for token pairs
    mapping(address => mapping(address => UniswapRoute[])) private customRoutes;

    /// @notice QuoteData structure to store Uniswap V3 quote information
    /// @param route The token path for the swap
    /// @param fees The fee tiers for each hop
    /// @param sqrtPriceX96AfterList The sqrt prices after each hop
    /// @param initializedTicksCrossedList The number of initialized ticks crossed for each hop
    struct QuoteData {
        address[] route;
        uint24[] fees;
        uint160[] sqrtPriceX96AfterList;
        uint32[] initializedTicksCrossedList;
    }

    /// @dev BestInQuote structure for internal stack depth optimization (quoteSwapIn)
    struct BestInQuote {
        uint256 cost;
        address[] route;
        uint24[] fees;
        uint160[] sqrtPriceAfterList;
        uint32[] ticksCrossed;
        bool found;
    }

    /// @dev BestOutQuote structure for internal stack depth optimization (quoteSwapOut)
    struct BestOutQuote {
        uint256 output;
        address[] route;
        uint24[] fees;
        uint160[] sqrtPriceAfterList;
        uint32[] ticksCrossed;
        bool found;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the UniswapV3SwapAdapter
    /// @param _quoter The address of the IUniswapV3ViewQuoter contract
    /// @param _router The address of the IUniswapV3SwapRouter contract
    /// @param _initialDefaultAdmin The address of the initial default admin
    /// @param _initialContractAdmin The address of the initial contract admin
    function initialize(
        address _quoter,
        address _router,
        address _initialDefaultAdmin,
        address _initialContractAdmin
    ) public initializer {
        __AccessControl_init();
        quoter = _quoter;
        router = _router;

        _grantRole(DEFAULT_ADMIN_ROLE, _initialDefaultAdmin);
        _grantRole(ADMIN_ROLE, _initialContractAdmin);
    }

    /// @notice Sets the IUniswapV3ViewQuoter contract address
    /// @param _quoter The address of the IUniswapV3ViewQuoter contract
    function setQuoter(address _quoter) external onlyRole(ADMIN_ROLE) {
        quoter = _quoter;
    }

    /// @notice Sets the IUniswapV3SwapRouter contract address
    /// @param _router The address of the IUniswapV3SwapRouter contract
    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
        router = _router;
    }

    /// @notice Adds a custom route for swapping tokens
    /// @param _tokenIn The token to swap from
    /// @param _tokenOut The token to swap to
    /// @param _route The route to swap through
    /// @param _fees The fee tiers for each hop in the route (must be one less than route length)
    function addRoute(
        address _tokenIn,
        address _tokenOut,
        address[] calldata _route,
        uint24[] calldata _fees
    ) external onlyRole(ADMIN_ROLE) {
        if (_route.length < 2) {
            revert InvalidRouteLength();
        }
        if (_route[0] != _tokenIn) {
            revert RouteMustStartWithTokenIn();
        }
        if (_route[_route.length - 1] != _tokenOut) {
            revert RouteMustEndWithTokenOut();
        }
        if (_route.length - 1 != _fees.length) {
            revert InvalidRouteLength();
        }

        // Create and store a new UniswapRoute
        UniswapRoute memory newRoute = UniswapRoute({path: _route, fees: _fees});

        customRoutes[_tokenIn][_tokenOut].push(newRoute);
    }

    /// @notice Removes a custom route for swapping tokens
    /// @param _tokenIn The token to swap from
    /// @param _tokenOut The token to swap to
    /// @param _routeIndex The index of the route to remove
    function removeRoute(address _tokenIn, address _tokenOut, uint256 _routeIndex) external onlyRole(ADMIN_ROLE) {
        if (_routeIndex >= customRoutes[_tokenIn][_tokenOut].length) {
            revert IndexOutOfBounds();
        }

        uint256 lastIndex = customRoutes[_tokenIn][_tokenOut].length - 1;
        if (_routeIndex < lastIndex) {
            // Copy the last element to the removed position
            customRoutes[_tokenIn][_tokenOut][_routeIndex] = customRoutes[_tokenIn][_tokenOut][lastIndex];
        }

        // Remove the last element
        customRoutes[_tokenIn][_tokenOut].pop();
    }

    /// @notice Clears all custom routes for swapping tokens.
    /// @param _tokenIn The token to swap from.
    /// @param _tokenOut The token to swap to.
    function clearRoutes(address _tokenIn, address _tokenOut) external onlyRole(ADMIN_ROLE) {
        delete customRoutes[_tokenIn][_tokenOut];
    }

    /// @notice Lists all custom routes for swapping tokens
    /// @param _tokenIn The token to swap from
    /// @param _tokenOut The token to swap to
    /// @return routes Array of UniswapRoute structs containing path and fees
    function listRoutes(address _tokenIn, address _tokenOut) external view returns (UniswapRoute[] memory) {
        return customRoutes[_tokenIn][_tokenOut];
    }

    /// @notice Encodes path for Uniswap V3 router
    /// @param _route The token route
    /// @param _fees The fee tiers for each hop
    /// @return encodedPath The encoded path bytes for the Uniswap router
    function _encodePath(address[] memory _route, uint24[] memory _fees) private pure returns (bytes memory) {
        bytes memory encodedPath = abi.encodePacked(_route[0]);
        for (uint256 i = 0; i < _fees.length; i++) {
            encodedPath = abi.encodePacked(encodedPath, _fees[i], _route[i + 1]);
        }
        return encodedPath;
    }

    /// @dev Encodes a path for a reverse-calculation (exact output) swap by starting from the end
    /// and prepending each hop. This is required for quoteExactOutput.
    function _encodeReversePath(address[] memory _route, uint24[] memory _fees) private pure returns (bytes memory) {
        bytes memory path = abi.encodePacked(_route[0]);
        for (uint256 i = 0; i < _fees.length; i++) {
            path = abi.encodePacked(_route[i + 1], _fees[i], path);
        }
        return path;
    }

    /// @inheritdoc IGildiExchangeSwapAdapter
    function quoteSwapIn(
        address _sourceToken,
        address _marketplaceToken,
        uint256 _marketplaceAmountDesired
    ) public view override returns (SwapInQuote memory quote) {
        UniswapRoute[] storage routes = customRoutes[_sourceToken][_marketplaceToken];

        // Store best quote data in a struct to reduce stack usage
        BestInQuote memory best;
        best.cost = type(uint256).max;
        best.found = false;

        if (routes.length == 0) {
            // Default single-hop route if no custom routes
            address[] memory defaultRoute = new address[](2);
            defaultRoute[0] = _sourceToken;
            defaultRoute[1] = _marketplaceToken;

            uint24[] memory uniDefaultFees = _getDefaultFees();

            for (uint256 i = 0; i < uniDefaultFees.length; i++) {
                uint24 poolFee = uniDefaultFees[i];

                uint24[] memory defaultFees = new uint24[](1);
                defaultFees[0] = poolFee;

                (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) = IUniswapV3ViewQuoter(
                    quoter
                ).quoteExactOutputSingle(
                        IUniswapV3ViewQuoter.QuoteExactOutputSingleParams({
                            tokenIn: _sourceToken,
                            tokenOut: _marketplaceToken,
                            amount: _marketplaceAmountDesired,
                            fee: defaultFees[0],
                            sqrtPriceLimitX96: 0
                        })
                    );
                // Only consider this a valid quote if amountIn is non-zero
                // Zero can be returned if the pool doesn't exist
                if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                    best.cost = amountIn;
                    best.route = defaultRoute;
                    best.fees = defaultFees;

                    best.sqrtPriceAfterList = new uint160[](1);
                    best.sqrtPriceAfterList[0] = sqrtPriceX96After;

                    best.ticksCrossed = new uint32[](1);
                    best.ticksCrossed[0] = initializedTicksCrossed;

                    best.found = true;
                }
            }
        } else {
            // Try all custom routes
            for (uint256 i = 0; i < routes.length; i++) {
                UniswapRoute storage route = routes[i];

                if (route.path.length == 2) {
                    // Single hop route
                    (
                        uint256 amountIn,
                        uint160 sqrtPriceX96After,
                        uint32 initializedTicksCrossed
                    ) = IUniswapV3ViewQuoter(quoter).quoteExactOutputSingle(
                            IUniswapV3ViewQuoter.QuoteExactOutputSingleParams({
                                tokenIn: route.path[0],
                                tokenOut: route.path[1],
                                amount: _marketplaceAmountDesired,
                                fee: route.fees[0],
                                sqrtPriceLimitX96: 0
                            })
                        );
                    // Only consider non-zero quotes as valid
                    if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                        best.cost = amountIn;
                        best.route = route.path;
                        best.fees = route.fees;

                        best.sqrtPriceAfterList = new uint160[](1);
                        best.sqrtPriceAfterList[0] = sqrtPriceX96After;

                        best.ticksCrossed = new uint32[](1);
                        best.ticksCrossed[0] = initializedTicksCrossed;

                        best.found = true;
                    }
                } else {
                    // Multi-hop route
                    bytes memory path = _encodeReversePath(route.path, route.fees);

                    (
                        uint256 amountIn,
                        uint160[] memory sqrtPriceX96AfterList,
                        uint32[] memory initializedTicksCrossedList
                    ) = IUniswapV3ViewQuoter(quoter).quoteExactOutput(path, _marketplaceAmountDesired);
                    // Only consider non-zero quotes as valid
                    if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                        best.cost = amountIn;
                        best.route = route.path;
                        best.fees = route.fees;
                        best.sqrtPriceAfterList = sqrtPriceX96AfterList;
                        best.ticksCrossed = initializedTicksCrossedList;
                        best.found = true;
                    }
                }
            }
        }

        // If we found a valid quote
        if (best.found) {
            // Package the quote data
            QuoteData memory quoteData = QuoteData({
                route: best.route,
                fees: best.fees,
                sqrtPriceX96AfterList: best.sqrtPriceAfterList,
                initializedTicksCrossedList: best.ticksCrossed
            });

            bytes memory rawQuoteData = abi.encode(quoteData);

            // Build the quoteRoute for return
            uint128[] memory amounts = new uint128[](best.route.length);
            amounts[0] = uint128(best.cost); // Input amount
            amounts[best.route.length - 1] = uint128(_marketplaceAmountDesired); // Output amount

            uint128[] memory feesArr = new uint128[](best.fees.length);
            for (uint256 i = 0; i < best.fees.length; i++) {
                feesArr[i] = uint128(best.fees[i]);
            }

            QuoteRoute memory quoteRoute = QuoteRoute({
                marketplaceAdapter: address(this),
                route: best.route,
                fees: feesArr,
                amounts: amounts,
                virtualAmountsWithoutSlippage: new uint128[](best.route.length) // Not used in Uniswap V3
            });

            // Build the final quote struct
            quote = SwapInQuote({
                sourceTokenRequired: best.cost,
                rawQuoteData: rawQuoteData,
                quoteRoute: quoteRoute,
                validRoute: true
            });
        } else {
            // No valid quote found
            quote.validRoute = false;
        }

        return quote;
    }

    /// @inheritdoc IGildiExchangeSwapAdapter
    function swapIn(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmountMax,
        uint256 _marketplaceAmount,
        address _to,
        bytes memory _quoteData
    ) external override returns (uint256 sourceSpent) {
        if (_quoteData.length == 0) {
            // Get the quote data by calling quoteSwapIn
            SwapInQuote memory quote = quoteSwapIn(_sourceToken, _targetToken, _marketplaceAmount);

            // Check if the quote is valid
            if (!quote.validRoute) {
                revert NoValidRoute();
            }

            _quoteData = quote.rawQuoteData;
        }

        // Decode the quote data
        QuoteData memory quoteData = abi.decode(_quoteData, (QuoteData));

        // Pull tokens from sender
        IERC20(_sourceToken).safeTransferFrom(msg.sender, address(this), _sourceAmountMax);

        // Approve router to spend tokens if needed
        uint256 allowance = IERC20(_sourceToken).allowance(address(this), router);
        if (allowance < _sourceAmountMax) {
            IERC20(_sourceToken).forceApprove(router, type(uint256).max);
        }

        if (quoteData.route.length == 2) {
            // Single hop swap
            IUniswapV3SwapRouter02.ExactOutputSingleParams memory params = IUniswapV3SwapRouter02
                .ExactOutputSingleParams({
                    tokenIn: quoteData.route[0],
                    tokenOut: quoteData.route[1],
                    fee: quoteData.fees[0],
                    recipient: _to,
                    amountOut: _marketplaceAmount,
                    amountInMaximum: _sourceAmountMax,
                    sqrtPriceLimitX96: 0
                });

            // Execute the swap
            sourceSpent = IUniswapV3SwapRouter02(router).exactOutputSingle(params);
        } else {
            // Multi-hop swap
            bytes memory path = _encodeReversePath(quoteData.route, quoteData.fees);

            IUniswapV3SwapRouter02.ExactOutputParams memory params = IUniswapV3SwapRouter02.ExactOutputParams({
                path: path,
                recipient: _to,
                amountOut: _marketplaceAmount,
                amountInMaximum: _sourceAmountMax
            });

            // Execute the swap
            sourceSpent = IUniswapV3SwapRouter02(router).exactOutput(params);
        }

        // Return unused tokens
        if (sourceSpent < _sourceAmountMax) {
            IERC20(_sourceToken).safeTransfer(_to, _sourceAmountMax - sourceSpent);
        }

        if (sourceSpent > _sourceAmountMax) {
            revert ExceededMaxAmount();
        }

        return sourceSpent;
    }

    /// @inheritdoc IGildiExchangeSwapAdapter
    function quoteSwapOut(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount
    ) public view override returns (SwapOutQuote memory quote) {
        UniswapRoute[] storage routes = customRoutes[_sourceToken][_targetToken];

        // Store best quote data in a struct to reduce stack usage
        BestOutQuote memory best;
        best.output = 0;
        best.found = false;

        if (routes.length == 0) {
            // Default single-hop route if no custom routes
            address[] memory defaultRoute = new address[](2);
            defaultRoute[0] = _sourceToken;
            defaultRoute[1] = _targetToken;

            uint24[] memory uniDefaultFees = _getDefaultFees();

            for (uint256 i = 0; i < uniDefaultFees.length; i++) {
                uint24 poolFee = uniDefaultFees[i];

                // Default fee tier for the pool (0.3%)
                uint24[] memory defaultFees = new uint24[](1);
                defaultFees[0] = poolFee;

                (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) = IUniswapV3ViewQuoter(
                    quoter
                ).quoteExactInputSingle(
                        IUniswapV3ViewQuoter.QuoteExactInputSingleParams({
                            tokenIn: _sourceToken,
                            tokenOut: _targetToken,
                            amountIn: _sourceAmount,
                            fee: defaultFees[0],
                            sqrtPriceLimitX96: 0
                        })
                    );
                // Only consider this a valid quote if amountOut is non-zero
                // Zero can be returned if the pool doesn't exist
                if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                    best.output = amountOut;
                    best.route = defaultRoute;
                    best.fees = defaultFees;

                    best.sqrtPriceAfterList = new uint160[](1);
                    best.sqrtPriceAfterList[0] = sqrtPriceX96After;

                    best.ticksCrossed = new uint32[](1);
                    best.ticksCrossed[0] = initializedTicksCrossed;

                    best.found = true;
                }
            }
        } else {
            // Try all custom routes
            for (uint256 i = 0; i < routes.length; i++) {
                UniswapRoute storage route = routes[i];

                if (route.path.length == 2) {
                    // Single hop route
                    (
                        uint256 amountOut,
                        uint160 sqrtPriceX96After,
                        uint32 initializedTicksCrossed
                    ) = IUniswapV3ViewQuoter(quoter).quoteExactInputSingle(
                            IUniswapV3ViewQuoter.QuoteExactInputSingleParams({
                                tokenIn: _sourceToken,
                                tokenOut: _targetToken,
                                amountIn: _sourceAmount,
                                fee: route.fees[0],
                                sqrtPriceLimitX96: 0
                            })
                        );

                    // Only consider non-zero quotes as valid
                    if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                        best.output = amountOut;
                        best.route = route.path;
                        best.fees = route.fees;

                        best.sqrtPriceAfterList = new uint160[](1);
                        best.sqrtPriceAfterList[0] = sqrtPriceX96After;

                        best.ticksCrossed = new uint32[](1);
                        best.ticksCrossed[0] = initializedTicksCrossed;
                        best.found = true;
                    }
                } else {
                    // Multi-hop route
                    bytes memory path = _encodePath(route.path, route.fees);
                    (
                        uint256 amountOut,
                        uint160[] memory sqrtPriceX96AfterList,
                        uint32[] memory initializedTicksCrossedList
                    ) = IUniswapV3ViewQuoter(quoter).quoteExactInput(path, _sourceAmount);
                    // Only consider non-zero quotes as valid
                    if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                        best.output = amountOut;
                        best.route = route.path;
                        best.fees = route.fees;
                        best.sqrtPriceAfterList = sqrtPriceX96AfterList;
                        best.ticksCrossed = initializedTicksCrossedList;
                        best.found = true;
                    }
                }
            }
        }

        // If we found a valid quote
        if (best.found) {
            // Package the quote data
            QuoteData memory quoteData = QuoteData({
                route: best.route,
                fees: best.fees,
                sqrtPriceX96AfterList: best.sqrtPriceAfterList,
                initializedTicksCrossedList: best.ticksCrossed
            });

            // Build the quoteRoute for return
            uint128[] memory amounts = new uint128[](best.route.length);
            amounts[0] = uint128(_sourceAmount); // Input amount
            amounts[best.route.length - 1] = uint128(best.output); // Output amount

            uint128[] memory feesArr = new uint128[](best.fees.length);
            for (uint256 i = 0; i < best.fees.length; i++) {
                feesArr[i] = uint128(best.fees[i]);
            }

            QuoteRoute memory quoteRoute = QuoteRoute({
                marketplaceAdapter: address(this),
                route: best.route,
                fees: feesArr,
                amounts: amounts,
                virtualAmountsWithoutSlippage: new uint128[](best.route.length) // Not used in Uniswap V3
            });

            quote = SwapOutQuote({
                targetTokenOut: best.output,
                rawQuoteData: abi.encode(quoteData),
                quoteRoute: quoteRoute,
                validRoute: true
            });
        } else {
            // Return invalid route if no quote found
            quote.validRoute = false;
        }

        return quote;
    }

    /// @inheritdoc IGildiExchangeSwapAdapter
    function swapOut(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount,
        uint256 _minimumAmountOut,
        address _to,
        bytes memory _quoteData
    ) external override returns (uint256 targetTokenReceived) {
        if (_quoteData.length == 0) {
            // Get the quote data by calling quoteSwapOut
            SwapOutQuote memory quote = quoteSwapOut(_sourceToken, _targetToken, _sourceAmount);

            // Check if the quote is valid
            if (!quote.validRoute) {
                revert NoValidRoute();
            }

            _quoteData = quote.rawQuoteData;
        }

        // Decode the quote data
        QuoteData memory quoteData = abi.decode(_quoteData, (QuoteData));

        // Pull tokens from sender
        IERC20(_sourceToken).safeTransferFrom(msg.sender, address(this), _sourceAmount);

        // Approve router to spend tokens if needed
        uint256 allowance = IERC20(_sourceToken).allowance(address(this), router);
        if (allowance < _sourceAmount) {
            IERC20(_sourceToken).forceApprove(router, type(uint256).max);
        }

        if (quoteData.route.length == 2) {
            // Single hop swap
            IUniswapV3SwapRouter02.ExactInputSingleParams memory params = IUniswapV3SwapRouter02
                .ExactInputSingleParams({
                    tokenIn: _sourceToken,
                    tokenOut: _targetToken,
                    fee: quoteData.fees[0],
                    recipient: _to,
                    amountIn: _sourceAmount,
                    amountOutMinimum: _minimumAmountOut,
                    sqrtPriceLimitX96: 0
                });

            // Execute the swap
            targetTokenReceived = IUniswapV3SwapRouter02(router).exactInputSingle(params);
        } else {
            // Multi-hop swap
            bytes memory path = _encodePath(quoteData.route, quoteData.fees);

            IUniswapV3SwapRouter02.ExactInputParams memory params = IUniswapV3SwapRouter02.ExactInputParams({
                path: path,
                recipient: _to,
                amountIn: _sourceAmount,
                amountOutMinimum: _minimumAmountOut
            });

            // Execute the swap
            targetTokenReceived = IUniswapV3SwapRouter02(router).exactInput(params);
        }

        if (targetTokenReceived < _minimumAmountOut) {
            revert InsufficientOutputAmount();
        }

        return targetTokenReceived;
    }

    /// @dev Returns the default fee tiers for Uniswap V3
    function _getDefaultFees() private pure returns (uint24[] memory defaultFees) {
        defaultFees = new uint24[](4);
        defaultFees[0] = 3000; // 0.30%
        defaultFees[1] = 500; // 0.05%
        defaultFees[2] = 10000; // 1.00%
        defaultFees[3] = 100; // 0.01%
        return defaultFees;
    }
}
