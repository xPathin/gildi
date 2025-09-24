// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '@openzeppelin/contracts/access/AccessControl.sol';

/// @title Mock Token
/// @notice Abstract contract for mock tokens, makes sure that the contract has a minter role
/// @dev This contract is for testing purposes only
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
abstract contract MockToken is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
}
