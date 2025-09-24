// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity >=0.5.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Wrapped Native Token Interface
/// @notice Interface for wrapped native tokens (e.g., WETH, WPOL) that can wrap/unwrap native currency
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface IWNative is IERC20 {
    /// @notice Deposit native currency and receive wrapped tokens
    /// @dev Mints wrapped tokens equivalent to the native currency sent
    function deposit() external payable;
    
    /// @notice Withdraw wrapped tokens and receive native currency
    /// @dev Burns wrapped tokens and sends equivalent native currency to caller
    /// @param amount The amount of wrapped tokens to withdraw
    function withdraw(uint256 amount) external;
}
