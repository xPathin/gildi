// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import './MockERC20Token.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

/// @title MockERC20Token
/// @dev This contract is used for testing purposes only.
/// @notice Anm abstract ERC20 token with permit that is used for testing purposes only.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract MockERC20TokenBurnable is MockERC20Token, ERC20Burnable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _defaultAdmin
    ) MockERC20Token(_name, _symbol, _decimals, _defaultAdmin) {}

    /// @inheritdoc ERC20
    function decimals() public view virtual override(ERC20, MockERC20Token) returns (uint8) {
        return super.decimals();
    }
}
