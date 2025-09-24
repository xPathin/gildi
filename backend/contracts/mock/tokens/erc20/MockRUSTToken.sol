// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import './MockERC20TokenBurnable.sol';

/// @title MockRUSTToken
/// @notice Mock contract for the Rusty Robot Country Club token
/// @dev This contract is for testing purposes only
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract MockRUSTToken is MockERC20TokenBurnable {
    /// @notice Initialize the MockRUSTToken contract
    /// @dev Sets up the ERC20 token with name "Mock Rusty Robot Country Club", symbol "mRUST", and 18 decimals
    /// @param _defaultAdmin The address that will have admin privileges for the token
    constructor(
        address _defaultAdmin
    ) MockERC20TokenBurnable('Mock Rusty Robot Country Club', 'mRUST', 18, _defaultAdmin) {}
}
