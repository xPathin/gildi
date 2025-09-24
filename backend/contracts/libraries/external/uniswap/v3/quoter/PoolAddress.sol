// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity ^0.8.0;

/// @title PoolAddress Library
/// @notice Provides functions for computing Uniswap V3 pool addresses
/// @author Gildi Company
library PoolAddress {
    /// @dev The init code hash used in the pool address calculation
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice Represents the identifying key for a Uniswap V3 pool
    /// @param token0 The first token of the pair
    /// @param token1 The second token of the pair
    /// @param fee The fee level of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @dev Creates a pool key for the given tokens and fee
    /// @param _tokenA The first token of the pair
    /// @param _tokenB The second token of the pair
    /// @param _fee The fee level of the pool
    /// @return key The pool key with tokens sorted by address
    function getPoolKey(address _tokenA, address _tokenB, uint24 _fee) internal pure returns (PoolKey memory key) {
        if (_tokenA > _tokenB) (_tokenA, _tokenB) = (_tokenB, _tokenA);
        return PoolKey({token0: _tokenA, token1: _tokenB, fee: _fee});
    }

    /// @dev Computes the address of a Uniswap V3 pool from its components
    /// @param _factory The Uniswap V3 factory contract address
    /// @param _key The PoolKey for the desired pool
    /// @return pool The calculated address of the pool
    function computePoolAddress(address _factory, PoolKey memory _key) internal pure returns (address pool) {
        (address token0, address token1) = (_key.token0, _key.token1);
        if (token0 > token1) (token0, token1) = (token1, token0);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            _factory,
                            keccak256(abi.encode(_key.token0, _key.token1, _key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
