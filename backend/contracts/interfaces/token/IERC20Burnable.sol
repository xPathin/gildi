// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

/// @title IERC20Burnable
/// @notice Interface for openzeppelin ERC20Burnable
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
interface IERC20Burnable {
    /// @notice Destroys a `value` amount of tokens from the caller.
    /// @param value The amount of tokens to destroy.
    function burn(uint256 value) external;

    /// @notice Destroys a `value` amount of tokens from `account`, deducting from the caller's allowance.
    /// @param account The account to destroy the tokens from.
    /// @param value The amount of tokens to destroy.
    function burnFrom(address account, uint256 value) external;
}
