// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import './MockERC20Token.sol';

/// @title MockUSDCToken
/// @notice Mock contract for the USDC token
/// @dev This contract is for testing purposes only
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract MockUSDCToken is MockERC20Token {
    /// @notice Initialize the MockUSDCToken contract
    /// @dev Sets up the ERC20 token with name "Mock USD Coin", symbol "mUSDC", and 6 decimals
    /// @param _defaultAdmin The address that will have admin privileges for the token
    constructor(address _defaultAdmin) MockERC20Token('Mock USD Coin', 'mUSDC', 6, _defaultAdmin) {}
}
