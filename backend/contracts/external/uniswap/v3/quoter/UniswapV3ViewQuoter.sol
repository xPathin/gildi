// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {IUniswapV3ViewQuoter} from '../../../../interfaces/external/uniswap/v3/quoter/IUniswapV3ViewQuoter.sol';
import {PoolAddress} from '../../../../libraries/external/uniswap/v3/quoter/PoolAddress.sol';
import {QuoterMath} from '../../../../libraries/external/uniswap/v3/quoter/QuoterMath.sol';
import {TickMath} from '../../../../libraries/external/uniswap/v3/core/TickMath.sol';
import {Path} from '../../../../libraries/external/uniswap/v3/periphery/Path.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {LowGasSafeMath} from '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';
import {SafeCast} from '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/// @title UniswapV3ViewQuoter Contract
/// @notice A contract that provides quotes for swaps in Uniswap V3 pools
/// @author Gildi Company
contract UniswapV3ViewQuoter is IUniswapV3ViewQuoter, Initializable {
    using QuoterMath for *;
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Path for bytes;

    // The v3 factory address
    address public factory;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract.
    /// @param _factory The Uniswap V3 factory address.
    function initialize(address _factory) public initializer {
        factory = _factory;
    }

    /// @dev Returns the pool address for the given token pair and fee
    /// @param _tokenA First token in the pair
    /// @param _tokenB Second token in the pair
    /// @param _fee Fee tier for the pool
    /// @return pool The address of the Uniswap V3 pool
    function getPoolAddress(address _tokenA, address _tokenB, uint24 _fee) private view returns (address pool) {
        pool = PoolAddress.computePoolAddress(factory, PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactInputSingleWithPool(
        QuoteExactInputSingleWithPoolParams memory params
    ) public view override returns (uint256 amountReceived, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) {
        int256 amount0;
        int256 amount1;

        bool zeroForOne = params.tokenIn < params.tokenOut;
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);

        // we need to pack a few variables to get under the stack limit
        QuoterMath.QuoteParams memory quoteParams = QuoterMath.QuoteParams({
            zeroForOne: zeroForOne,
            fee: params.fee,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            exactInput: false
        });

        (amount0, amount1, sqrtPriceX96After, initializedTicksCrossed) = QuoterMath.quote(
            pool,
            params.amountIn.toInt256(),
            quoteParams
        );

        amountReceived = amount0 > 0 ? uint256(-amount1) : uint256(-amount0);
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory _params
    ) public view override returns (uint256 amountReceived, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) {
        address poolAddress = getPoolAddress(_params.tokenIn, _params.tokenOut, _params.fee);

        QuoteExactInputSingleWithPoolParams memory poolParams = QuoteExactInputSingleWithPoolParams({
            tokenIn: _params.tokenIn,
            tokenOut: _params.tokenOut,
            amountIn: _params.amountIn,
            fee: _params.fee,
            pool: poolAddress,
            sqrtPriceLimitX96: 0
        });

        (amountReceived, sqrtPriceX96After, initializedTicksCrossed) = quoteExactInputSingleWithPool(poolParams);
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactInput(
        bytes memory _path,
        uint256 _amountIn
    )
        public
        view
        override
        returns (uint256 amountOut, uint160[] memory sqrtPriceX96AfterList, uint32[] memory initializedTicksCrossedList)
    {
        sqrtPriceX96AfterList = new uint160[](_path.numPools());
        initializedTicksCrossedList = new uint32[](_path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenIn, address tokenOut, uint24 fee) = _path.decodeFirstPool();
            (uint256 _amountOut, uint160 _sqrtPriceX96After, uint32 initializedTicksCrossed) = quoteExactInputSingle(
                QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: fee,
                    amountIn: _amountIn,
                    sqrtPriceLimitX96: 0
                })
            );

            sqrtPriceX96AfterList[i] = _sqrtPriceX96After;
            initializedTicksCrossedList[i] = initializedTicksCrossed;
            _amountIn = _amountOut;
            i++;

            if (_path.hasMultiplePools()) {
                _path = _path.skipToken();
            } else {
                return (_amountIn, sqrtPriceX96AfterList, initializedTicksCrossedList);
            }
        }
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactOutputSingleWithPool(
        QuoteExactOutputSingleWithPoolParams memory _params
    ) public view override returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) {
        int256 amount0;
        int256 amount1;
        uint256 amountReceived;

        bool zeroForOne = _params.tokenIn < _params.tokenOut;
        IUniswapV3Pool pool = IUniswapV3Pool(_params.pool);

        QuoterMath.QuoteParams memory quoteParams = QuoterMath.QuoteParams({
            zeroForOne: zeroForOne,
            exactInput: true, // will be overridden
            fee: _params.fee,
            sqrtPriceLimitX96: _params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : _params.sqrtPriceLimitX96
        });

        (amount0, amount1, sqrtPriceX96After, initializedTicksCrossed) = QuoterMath.quote(
            pool,
            -(_params.amount.toInt256()),
            quoteParams
        );

        amountIn = amount0 > 0 ? uint256(amount0) : uint256(amount1);
        amountReceived = amount0 > 0 ? uint256(-amount1) : uint256(-amount0);
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactOutputSingle(
        QuoteExactOutputSingleParams memory _params
    ) public view override returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed) {
        address poolAddress = getPoolAddress(_params.tokenIn, _params.tokenOut, _params.fee);

        QuoteExactOutputSingleWithPoolParams memory poolParams = QuoteExactOutputSingleWithPoolParams({
            tokenIn: _params.tokenIn,
            tokenOut: _params.tokenOut,
            amount: _params.amount,
            fee: _params.fee,
            pool: poolAddress,
            sqrtPriceLimitX96: 0
        });

        (amountIn, sqrtPriceX96After, initializedTicksCrossed) = quoteExactOutputSingleWithPool(poolParams);
    }

    /// @inheritdoc IUniswapV3ViewQuoter
    function quoteExactOutput(
        bytes memory _path,
        uint256 _amountOut
    )
        public
        view
        override
        returns (uint256 amountIn, uint160[] memory sqrtPriceX96AfterList, uint32[] memory initializedTicksCrossedList)
    {
        sqrtPriceX96AfterList = new uint160[](_path.numPools());
        initializedTicksCrossedList = new uint32[](_path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenOut, address tokenIn, uint24 fee) = _path.decodeFirstPool();

            (uint256 _amountIn, uint160 _sqrtPriceX96After, uint32 _initializedTicksCrossed) = quoteExactOutputSingle(
                QuoteExactOutputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amount: _amountOut,
                    fee: fee,
                    sqrtPriceLimitX96: 0
                })
            );

            sqrtPriceX96AfterList[i] = _sqrtPriceX96After;
            initializedTicksCrossedList[i] = _initializedTicksCrossed;
            _amountOut = _amountIn;
            i++;

            if (_path.hasMultiplePools()) {
                _path = _path.skipToken();
            } else {
                return (_amountOut, sqrtPriceX96AfterList, initializedTicksCrossedList);
            }
        }
    }
}
