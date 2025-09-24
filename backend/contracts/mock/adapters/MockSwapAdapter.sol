// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '../../interfaces/marketplace/exchange/IGildiExchangeSwapAdapter.sol';
import '../../interfaces/oracles/price/IGildiPriceOracle.sol';
import '../tokens/erc20/MockERC20Token.sol';
import {ContextUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

/// @title MockSwapAdapter
/// @notice A mock adapter that simulates DEX behavior with on-demand token minting
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract MockSwapAdapter is IGildiExchangeSwapAdapter, Initializable, ContextUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @dev Array of custom routes for each token pair
    mapping(address => mapping(address => MockRoute[])) private customRoutes;

    /// @dev Tracks all token pairs that have one or more configured routes
    TokenPair[] private allTokenPairs;

    /// @notice Address of the GildiPriceOracle contract
    address public gildiPriceOracle;

    /// @dev Mapping of token pairs to oracle pair IDs (tokenA => tokenB => pairId)
    mapping(address => mapping(address => bytes32)) private oraclePairIds;

    /// @dev Base rate used for display-only calculations (1e18)
    uint256 private constant BASE_RATE = 1e18;

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
    /// @dev Emitted when a token is not a MockERC20Token
    error TokenNotMockable();
    /// @dev Emitted when exchange rate is zero or invalid
    error InvalidExchangeRate();
    /// @dev Emitted when price oracle address is zero
    error InvalidPriceOracle();
    /// @dev Emitted when assets are not found in price oracle
    error AssetsNotFoundInOracle();
    /// @dev Emitted when fee rate is invalid (must be < 1_000_000)
    error InvalidFeeRate();

    /// @notice Struct to represent a mock route
    /// @dev Combines token path and fees as a single unit
    struct MockRoute {
        address[] path; // The tokens in the route
        uint24[] fees; // The fees for each hop in Uniswap v3 fee units (parts per million). Example: 3000 = 0.30%
    }

    /// @notice QuoteData structure to store mock quote information
    /// @param route The token path for the swap
    /// @param fees The fee tiers for each hop
    /// @param exchangeRates The exchange rates for each hop (display-only, 1e18 floor)
    struct QuoteData {
        address[] route;
        uint24[] fees;
        uint256[] exchangeRates;
    }

    /// @dev BestInQuote structure for internal stack depth optimization (quoteSwapIn)
    struct BestInQuote {
        uint256 cost;
        address[] route;
        uint24[] fees;
        uint256[] exchangeRates;
        bool found;
    }

    /// @dev BestOutQuote structure for internal stack depth optimization (quoteSwapOut)
    struct BestOutQuote {
        uint256 output;
        address[] route;
        uint24[] fees;
        uint256[] exchangeRates;
        bool found;
    }

    /// @dev Array to track all token pairs for clearAllRoutes functionality
    struct TokenPair {
        address tokenIn;
        address tokenOut;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the MockSwapAdapter
    /// @param _gildiPriceOracle The address of the GildiPriceOracle contract
    /// @param _initialDefaultAdmin The address of the initial default admin
    /// @param _initialContractAdmin The address of the initial contract admin
    function initialize(
        address _gildiPriceOracle,
        address _initialDefaultAdmin,
        address _initialContractAdmin
    ) public initializer {
        __AccessControl_init();
        gildiPriceOracle = _gildiPriceOracle;

        _grantRole(DEFAULT_ADMIN_ROLE, _initialDefaultAdmin);
        _grantRole(ADMIN_ROLE, _initialContractAdmin);
    }

    /// @notice Sets the GildiPriceOracle address
    /// @param _gildiPriceOracle The address of the GildiPriceOracle contract
    function setGildiPriceOracle(address _gildiPriceOracle) external onlyRole(ADMIN_ROLE) {
        gildiPriceOracle = _gildiPriceOracle;
    }

    /// @notice Sets the oracle pair ID for a token pair
    /// @param _tokenPair The token pair
    /// @param _pairId The oracle pair ID for this token pair
    function setOraclePairId(TokenPair memory _tokenPair, bytes32 _pairId) external onlyRole(ADMIN_ROLE) {
        oraclePairIds[_tokenPair.tokenIn][_tokenPair.tokenOut] = _pairId;
    }

    /// @notice Gets the oracle pair ID for a token pair
    /// @param _tokenPair The token pair
    /// @return pairId The oracle pair ID, or bytes32(0) if not set
    function getOraclePairId(TokenPair memory _tokenPair) external view returns (bytes32 pairId) {
        return oraclePairIds[_tokenPair.tokenIn][_tokenPair.tokenOut];
    }

    /// @notice Gets a display exchange rate (floor) such that: tokenA_amount * rate / 1e18 = tokenB_amount
    function getExchangeRate(TokenPair memory _tokenPair) external view returns (uint256 rate) {
        (uint256 num, uint256 den) = _getOracleRateFrac(_tokenPair.tokenIn, _tokenPair.tokenOut);
        if (num == 0 || den == 0) {
            return 0;
        }
        return Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);
    }

    /// @notice Adds a custom route for swapping tokens
    /// @param _pair The token pair for which to add the route
    /// @param _route The route to swap through
    /// @param _fees The fee tiers for each hop in the route (must be one less than route length). Units are parts per million.
    function addRoute(
        TokenPair memory _pair,
        address[] calldata _route,
        uint24[] calldata _fees
    ) external onlyRole(ADMIN_ROLE) {
        if (_route.length < 2) {
            revert InvalidRouteLength();
        }
        if (_route[0] != _pair.tokenIn) {
            revert RouteMustStartWithTokenIn();
        }
        if (_route[_route.length - 1] != _pair.tokenOut) {
            revert RouteMustEndWithTokenOut();
        }
        if (_route.length - 1 != _fees.length) {
            revert InvalidRouteLength();
        }

        // Validate fee units
        for (uint256 i = 0; i < _fees.length; i++) {
            if (_fees[i] >= 1_000_000) {
                revert InvalidFeeRate();
            }
        }

        // Create and store a new MockRoute
        MockRoute memory newRoute = MockRoute({path: _route, fees: _fees});

        customRoutes[_pair.tokenIn][_pair.tokenOut].push(newRoute);

        // Track that this token pair has routes (only add if not already tracked)
        if (!_isTokenPairTracked(_pair)) {
            allTokenPairs.push(_pair);
        }
    }

    /// @notice Removes a custom route for swapping tokens
    /// @param _routeIndex The index of the route to remove
    function removeRoute(TokenPair memory _tokenPair, uint256 _routeIndex) external onlyRole(ADMIN_ROLE) {
        if (_routeIndex >= customRoutes[_tokenPair.tokenIn][_tokenPair.tokenOut].length) {
            revert IndexOutOfBounds();
        }

        uint256 lastIndex = customRoutes[_tokenPair.tokenIn][_tokenPair.tokenOut].length - 1;
        if (_routeIndex < lastIndex) {
            customRoutes[_tokenPair.tokenIn][_tokenPair.tokenOut][_routeIndex] = customRoutes[_tokenPair.tokenIn][
                _tokenPair.tokenOut
            ][lastIndex];
        }
        customRoutes[_tokenPair.tokenIn][_tokenPair.tokenOut].pop();

        if (customRoutes[_tokenPair.tokenIn][_tokenPair.tokenOut].length == 0) {
            _removeTokenPairFromArray(_tokenPair);
        }
    }

    /// @notice Clears all custom routes for swapping tokens for a specific token pair.
    /// @param _pair The token pair for which to clear the routes
    function clearRoutes(TokenPair memory _pair) external onlyRole(ADMIN_ROLE) {
        delete customRoutes[_pair.tokenIn][_pair.tokenOut];
        _removeTokenPairFromArray(_pair);
    }

    /// @notice Clears all custom routes for all token pairs
    function clearAllRoutes() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allTokenPairs.length; i++) {
            TokenPair storage pair = allTokenPairs[i];
            delete customRoutes[pair.tokenIn][pair.tokenOut];
        }
        delete allTokenPairs;
    }

    /// @notice Lists all custom routes for swapping tokens for a specific token pair.
    /// @param _pair The token pair for which to list the routes
    /// @return routes Array of MockRoute structs containing path and fees
    function listRoutes(TokenPair memory _pair) external view returns (MockRoute[] memory) {
        return customRoutes[_pair.tokenIn][_pair.tokenOut];
    }

    // ---------------------------------------------------------------------
    // Precision-first math: fractional oracle rates + Uniswap-style rounding
    // ---------------------------------------------------------------------

    /// @dev Euclidean GCD
    function _gcd(uint256 a, uint256 b) private pure returns (uint256) {
        while (b != 0) {
            uint256 t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    /// @dev Return price as a fraction num/den such that: out = in * num / den
    /// Fractions account for token decimal mismatch. Returns (0,0) if unavailable.
    function _getOracleRateFrac(address _tokenA, address _tokenB) private view returns (uint256 num, uint256 den) {
        if (gildiPriceOracle == address(0)) {
            return (0, 0);
        }

        bytes32 pairIdA = oraclePairIds[_tokenA][_tokenB];
        bytes32 pairIdB = oraclePairIds[_tokenB][_tokenA];
        if (pairIdA == bytes32(0) || pairIdB == bytes32(0)) {
            return (0, 0);
        }

        try IGildiPriceOracle(gildiPriceOracle).getPrice(pairIdA) returns (IGildiPriceResolver.PriceData memory pa) {
            try IGildiPriceOracle(gildiPriceOracle).getPrice(pairIdB) returns (
                IGildiPriceResolver.PriceData memory pb
            ) {
                uint8 da = MockERC20Token(_tokenA).decimals();
                uint8 db = MockERC20Token(_tokenB).decimals();

                // Normalize oracle prices to 18 decimals to avoid precision loss
                uint256 Pa = (pa.decimals <= 18)
                    ? pa.price * (10 ** (18 - pa.decimals))
                    : pa.price / (10 ** (pa.decimals - 18));
                uint256 Pb = (pb.decimals <= 18)
                    ? pb.price * (10 ** (18 - pb.decimals))
                    : pb.price / (10 ** (pb.decimals - 18));

                if (Pa == 0 || Pb == 0) {
                    return (0, 0);
                }

                if (db >= da) {
                    // F = (Pa * 10^(db-da)) / Pb
                    uint256 s = 10 ** (db - da);

                    // Reduce (Pa / Pb)
                    uint256 g1 = _gcd(Pa, Pb);
                    uint256 a = Pa / g1;
                    uint256 b = Pb / g1;

                    // Push as much of s into denominator as possible
                    uint256 g2 = _gcd(s, b);
                    uint256 s1 = s / g2;
                    uint256 b1 = b / g2;

                    num = a * s1;
                    den = b1;
                } else {
                    // F = Pa / (Pb * 10^(da-db))
                    uint256 s = 10 ** (da - db);

                    // Reduce Pa vs s, then vs Pb
                    uint256 g2 = _gcd(Pa, s);
                    uint256 a1 = Pa / g2;
                    uint256 s1 = s / g2;

                    uint256 g1 = _gcd(a1, Pb);
                    uint256 a2 = a1 / g1;
                    uint256 b2 = Pb / g1;

                    num = a2;
                    den = b2 * s1;
                }

                if (den == 0) {
                    return (0, 0);
                }

                // For logs: floor display rate (omitted to avoid unused variable)
                return (num, den);
            } catch {
                return (0, 0);
            }
        } catch {
            return (0, 0);
        }
    }

    /// @dev Exact-input: apply fee then floor
    function _amountOutViaFrac(uint256 amountIn, uint256 num, uint256 den, uint24 fee) private pure returns (uint256) {
        if (fee >= 1_000_000) {
            revert InvalidFeeRate();
        }
        // Apply fee to input (round DOWN)
        uint256 effectiveIn = Math.mulDiv(amountIn, (1_000_000 - fee), 1_000_000, Math.Rounding.Floor);
        // Multiply by fraction (round DOWN)
        return Math.mulDiv(effectiveIn, num, den, Math.Rounding.Floor);
    }

    /// @dev Exact-output: invert then ceil, including fee-on-input
    function _amountInViaFrac(uint256 amountOut, uint256 num, uint256 den, uint24 fee) private pure returns (uint256) {
        if (fee >= 1_000_000) {
            revert InvalidFeeRate();
        }
        if (num == 0 || den == 0) {
            revert InvalidExchangeRate();
        }
        // Gross (pre-fee) input: ceil(amountOut * den / num)
        uint256 grossNoFee = Math.mulDiv(amountOut, den, num, Math.Rounding.Ceil);
        // Undo fee on input: ceil(gross / (1 - f))
        return Math.mulDiv(grossNoFee, 1_000_000, (1_000_000 - fee), Math.Rounding.Ceil);
    }

    // ---------------------------------------------------------
    // Multi-hop simulators (use fractions + correct rounding)
    // ---------------------------------------------------------

    /// @dev Simulates a multi-hop swap calculation for exact output (reverse)
    function _simulateMultiHopOut(
        address[] memory _route,
        uint24[] memory _fees,
        uint256 _finalAmountOut
    ) private view returns (uint256 totalAmountIn, uint256[] memory displayRates) {
        displayRates = new uint256[](_fees.length);
        uint256 currentAmountOut = _finalAmountOut;

        for (uint256 i = _fees.length; i > 0; i--) {
            uint256 hopIndex = i - 1;
            address tokenIn = _route[hopIndex];
            address tokenOut = _route[hopIndex + 1];

            (uint256 num, uint256 den) = _getOracleRateFrac(tokenIn, tokenOut);
            if (num == 0 || den == 0) {
                return (0, displayRates);
            }
            displayRates[hopIndex] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

            currentAmountOut = _amountInViaFrac(currentAmountOut, num, den, _fees[hopIndex]);
        }

        totalAmountIn = currentAmountOut;
    }

    /// @dev Simulates a multi-hop swap calculation for exact input (forward)
    function _simulateMultiHopIn(
        address[] memory _route,
        uint24[] memory _fees,
        uint256 _initialAmountIn
    ) private view returns (uint256 totalAmountOut, uint256[] memory displayRates) {
        displayRates = new uint256[](_fees.length);
        uint256 currentAmountIn = _initialAmountIn;

        for (uint256 i = 0; i < _fees.length; i++) {
            address tokenIn = _route[i];
            address tokenOut = _route[i + 1];

            (uint256 num, uint256 den) = _getOracleRateFrac(tokenIn, tokenOut);
            if (num == 0 || den == 0) {
                return (0, displayRates);
            }
            displayRates[i] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

            currentAmountIn = _amountOutViaFrac(currentAmountIn, num, den, _fees[i]);
        }

        totalAmountOut = currentAmountIn;
    }

    // ---------------------------------------------------------
    // Quoting & swapping (now using fractional math)
    // ---------------------------------------------------------

    /// @inheritdoc IGildiExchangeSwapAdapter
    function quoteSwapIn(
        address _sourceToken,
        address _marketplaceToken,
        uint256 _marketplaceAmountDesired
    ) public view override returns (SwapInQuote memory quote) {
        MockRoute[] storage routes = customRoutes[_sourceToken][_marketplaceToken];

        BestInQuote memory best;
        best.cost = type(uint256).max;

        if (routes.length == 0) {
            address[] memory defaultRoute = new address[](2);
            defaultRoute[0] = _sourceToken;
            defaultRoute[1] = _marketplaceToken;

            uint24[] memory defaultFees = _getDefaultFees();

            for (uint256 i = 0; i < defaultFees.length; i++) {
                uint24 poolFee = defaultFees[i];

                uint24[] memory routeFees = new uint24[](1);
                routeFees[0] = poolFee;

                (uint256 num, uint256 den) = _getOracleRateFrac(_sourceToken, _marketplaceToken);
                if (num == 0 || den == 0) {
                    continue;
                }

                uint256 amountIn = _amountInViaFrac(_marketplaceAmountDesired, num, den, poolFee);
                if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                    best.cost = amountIn;
                    best.route = defaultRoute;
                    best.fees = routeFees;

                    best.exchangeRates = new uint256[](1);
                    best.exchangeRates[0] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

                    best.found = true;
                }
            }
        } else {
            for (uint256 i = 0; i < routes.length; i++) {
                MockRoute storage route = routes[i];

                if (route.path.length == 2) {
                    (uint256 num, uint256 den) = _getOracleRateFrac(route.path[0], route.path[1]);
                    if (num == 0 || den == 0) {
                        continue;
                    }

                    uint256 amountIn = _amountInViaFrac(_marketplaceAmountDesired, num, den, route.fees[0]);
                    if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                        best.cost = amountIn;
                        best.route = route.path;
                        best.fees = route.fees;

                        best.exchangeRates = new uint256[](1);
                        best.exchangeRates[0] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

                        best.found = true;
                    }
                } else {
                    (uint256 amountIn, uint256[] memory rates) = _simulateMultiHopOut(
                        route.path,
                        route.fees,
                        _marketplaceAmountDesired
                    );

                    if (amountIn > 0 && (amountIn < best.cost || !best.found)) {
                        best.cost = amountIn;
                        best.route = route.path;
                        best.fees = route.fees;
                        best.exchangeRates = rates;
                        best.found = true;
                    }
                }
            }
        }

        if (best.found) {
            QuoteData memory quoteData = QuoteData({
                route: best.route,
                fees: best.fees,
                exchangeRates: best.exchangeRates
            });

            bytes memory rawQuoteData = abi.encode(quoteData);

            uint128[] memory amounts = new uint128[](best.route.length);
            amounts[0] = uint128(best.cost);
            amounts[best.route.length - 1] = uint128(_marketplaceAmountDesired);

            uint128[] memory feesArr = new uint128[](best.fees.length);
            for (uint256 i = 0; i < best.fees.length; i++) {
                feesArr[i] = uint128(best.fees[i]);
            }

            // virtualAmountsWithoutSlippage: omitted by request
            uint128[] memory emptyVirtual = new uint128[](best.route.length);

            QuoteRoute memory quoteRoute = QuoteRoute({
                marketplaceAdapter: address(this),
                route: best.route,
                fees: feesArr,
                amounts: amounts,
                virtualAmountsWithoutSlippage: emptyVirtual
            });

            quote = SwapInQuote({
                sourceTokenRequired: best.cost,
                rawQuoteData: rawQuoteData,
                quoteRoute: quoteRoute,
                validRoute: true
            });
        } else {
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
            SwapInQuote memory quote = quoteSwapIn(_sourceToken, _targetToken, _marketplaceAmount);
            if (!quote.validRoute) {
                revert NoValidRoute();
            }
            _quoteData = quote.rawQuoteData;
        }

        QuoteData memory quoteData = abi.decode(_quoteData, (QuoteData));

        // Validate route
        if (
            quoteData.route.length < 2 ||
            quoteData.fees.length != quoteData.route.length - 1 ||
            quoteData.route[0] != _sourceToken ||
            quoteData.route[quoteData.route.length - 1] != _targetToken
        ) {
            revert NoValidRoute();
        }

        if (quoteData.route.length == 2) {
            (uint256 num, uint256 den) = _getOracleRateFrac(quoteData.route[0], quoteData.route[1]);
            if (num == 0 || den == 0) {
                revert InvalidExchangeRate();
            }
            sourceSpent = _amountInViaFrac(_marketplaceAmount, num, den, uint24(quoteData.fees[0]));
        } else {
            (sourceSpent, ) = _simulateMultiHopOut(quoteData.route, quoteData.fees, _marketplaceAmount);
            if (sourceSpent == 0) {
                revert NoValidRoute();
            }
        }

        if (sourceSpent > _sourceAmountMax) {
            revert ExceededMaxAmount();
        }

        IERC20(_sourceToken).safeTransferFrom(msg.sender, address(this), sourceSpent);
        _mintTokenToAddress(_targetToken, _to, _marketplaceAmount);

        return sourceSpent;
    }

    /// @inheritdoc IGildiExchangeSwapAdapter
    function quoteSwapOut(
        address _sourceToken,
        address _targetToken,
        uint256 _sourceAmount
    ) public view override returns (SwapOutQuote memory quote) {
        MockRoute[] storage routes = customRoutes[_sourceToken][_targetToken];
        BestOutQuote memory best;

        if (routes.length == 0) {
            address[] memory defaultRoute = new address[](2);
            defaultRoute[0] = _sourceToken;
            defaultRoute[1] = _targetToken;

            uint24[] memory defaultFees = _getDefaultFees();

            for (uint256 i = 0; i < defaultFees.length; i++) {
                uint24 poolFee = defaultFees[i];

                uint24[] memory routeFees = new uint24[](1);
                routeFees[0] = poolFee;

                (uint256 num, uint256 den) = _getOracleRateFrac(_sourceToken, _targetToken);
                if (num == 0 || den == 0) {
                    continue;
                }

                uint256 amountOut = _amountOutViaFrac(_sourceAmount, num, den, poolFee);

                if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                    best.output = amountOut;
                    best.route = defaultRoute;
                    best.fees = routeFees;

                    best.exchangeRates = new uint256[](1);
                    best.exchangeRates[0] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

                    best.found = true;
                }
            }
        } else {
            for (uint256 i = 0; i < routes.length; i++) {
                MockRoute storage route = routes[i];

                if (route.path.length == 2) {
                    (uint256 num, uint256 den) = _getOracleRateFrac(route.path[0], route.path[1]);
                    if (num == 0 || den == 0) {
                        continue;
                    }

                    uint256 amountOut = _amountOutViaFrac(_sourceAmount, num, den, route.fees[0]);

                    if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                        best.output = amountOut;
                        best.route = route.path;
                        best.fees = route.fees;

                        best.exchangeRates = new uint256[](1);
                        best.exchangeRates[0] = Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);

                        best.found = true;
                    }
                } else {
                    (uint256 amountOut, uint256[] memory rates) = _simulateMultiHopIn(
                        route.path,
                        route.fees,
                        _sourceAmount
                    );

                    if (amountOut > 0 && (amountOut > best.output || !best.found)) {
                        best.output = amountOut;
                        best.route = route.path;
                        best.fees = route.fees;
                        best.exchangeRates = rates;
                        best.found = true;
                    }
                }
            }
        }

        if (best.found) {
            QuoteData memory quoteData = QuoteData({
                route: best.route,
                fees: best.fees,
                exchangeRates: best.exchangeRates
            });

            uint128[] memory amounts = new uint128[](best.route.length);
            amounts[0] = uint128(_sourceAmount);
            amounts[best.route.length - 1] = uint128(best.output);

            uint128[] memory feesArr = new uint128[](best.fees.length);
            for (uint256 i = 0; i < best.fees.length; i++) {
                feesArr[i] = uint128(best.fees[i]);
            }

            // virtualAmountsWithoutSlippage: omitted by request
            uint128[] memory emptyVirtual = new uint128[](best.route.length);

            QuoteRoute memory quoteRoute = QuoteRoute({
                marketplaceAdapter: address(this),
                route: best.route,
                fees: feesArr,
                amounts: amounts,
                virtualAmountsWithoutSlippage: emptyVirtual
            });

            quote = SwapOutQuote({
                targetTokenOut: best.output,
                rawQuoteData: abi.encode(quoteData),
                quoteRoute: quoteRoute,
                validRoute: true
            });
        } else {
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
            SwapOutQuote memory quote = quoteSwapOut(_sourceToken, _targetToken, _sourceAmount);
            if (!quote.validRoute) {
                revert NoValidRoute();
            }
            _quoteData = quote.rawQuoteData;
        }

        QuoteData memory quoteData = abi.decode(_quoteData, (QuoteData));

        // Validate route
        if (
            quoteData.route.length < 2 ||
            quoteData.fees.length != quoteData.route.length - 1 ||
            quoteData.route[0] != _sourceToken ||
            quoteData.route[quoteData.route.length - 1] != _targetToken
        ) {
            revert NoValidRoute();
        }

        if (quoteData.route.length == 2) {
            (uint256 num, uint256 den) = _getOracleRateFrac(quoteData.route[0], quoteData.route[1]);
            if (num == 0 || den == 0) {
                revert InvalidExchangeRate();
            }
            targetTokenReceived = _amountOutViaFrac(_sourceAmount, num, den, uint24(quoteData.fees[0]));
        } else {
            (targetTokenReceived, ) = _simulateMultiHopIn(quoteData.route, quoteData.fees, _sourceAmount);
            if (targetTokenReceived == 0) {
                revert NoValidRoute();
            }
        }

        if (targetTokenReceived < _minimumAmountOut) {
            revert InsufficientOutputAmount();
        }

        IERC20(_sourceToken).safeTransferFrom(msg.sender, address(this), _sourceAmount);
        _mintTokenToAddress(_targetToken, _to, targetTokenReceived);

        return targetTokenReceived;
    }

    /// @dev Mints tokens to a specific address if the token supports minting
    /// @param _token The token contract address
    /// @param _to The address to mint to
    /// @param _amount The amount to mint
    function _mintTokenToAddress(address _token, address _to, uint256 _amount) private {
        try MockERC20Token(_token).mint(_to, _amount) {
            // ok
        } catch {
            revert TokenNotMockable();
        }
    }

    /// @dev (Legacy) get scalar rate used for display/testing — floors to avoid optimism
    function _getOracleRate(address _tokenA, address _tokenB) private view returns (uint256 rate) {
        (uint256 num, uint256 den) = _getOracleRateFrac(_tokenA, _tokenB);
        if (num == 0 || den == 0) {
            return 0;
        }
        return Math.mulDiv(num, BASE_RATE, den, Math.Rounding.Floor);
    }

    /// @dev Gets asset ID by symbol from the oracle
    /// @param _symbol The token symbol
    /// @return assetId The asset ID, 0 if not found
    function _getAssetIdBySymbol(string memory _symbol) private view returns (uint256 assetId) {
        try IGildiPriceOracle(gildiPriceOracle).getAssets() returns (IGildiPriceOracle.Asset[] memory assets) {
            for (uint256 i = 0; i < assets.length; i++) {
                if (keccak256(bytes(assets[i].symbol)) == keccak256(bytes(_symbol))) {
                    return assets[i].id;
                }
            }
        } catch {}
        return 0;
    }

    /// @dev Returns the default fee tiers for mock swaps
    function _getDefaultFees() private pure returns (uint24[] memory defaultFees) {
        defaultFees = new uint24[](4);
        defaultFees[0] = 3000; // 0.30%
        defaultFees[1] = 500; // 0.05%
        defaultFees[2] = 10000; // 1.00%
        defaultFees[3] = 100; // 0.01%
        return defaultFees;
    }

    /// @dev Checks if a token pair is already being tracked
    function _isTokenPairTracked(TokenPair memory _pair) private view returns (bool exists) {
        for (uint256 i = 0; i < allTokenPairs.length; i++) {
            if (allTokenPairs[i].tokenIn == _pair.tokenIn && allTokenPairs[i].tokenOut == _pair.tokenOut) {
                return true;
            }
        }
        return false;
    }

    /// @dev Removes a token pair from the tracking array
    function _removeTokenPairFromArray(TokenPair memory _pair) private {
        for (uint256 i = 0; i < allTokenPairs.length; i++) {
            if (allTokenPairs[i].tokenIn == _pair.tokenIn && allTokenPairs[i].tokenOut == _pair.tokenOut) {
                if (i < allTokenPairs.length - 1) {
                    allTokenPairs[i] = allTokenPairs[allTokenPairs.length - 1];
                }
                allTokenPairs.pop();
                break;
            }
        }
    }
}
