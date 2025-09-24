// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import '../MockToken.sol';

/// @title MockERC20Token
/// @dev This contract is used for testing purposes only.
/// @notice Anm abstract ERC20 token with permit that is used for testing purposes only.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract MockERC20Token is ERC20, ERC20Permit, MockToken {
    uint8 private tokenDecimals;

    /// @notice Constructs the ERC20 token with permit.
    /// @dev If the decimals are greater than 18, it will be set to 18
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    /// @param _decimals The number of decimals for the token
    /// @param _defaultAdmin The initial default Administrator
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _defaultAdmin
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        if (_decimals > 18) {
            _decimals = 18;
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        tokenDecimals = _decimals;
    }

    /// @notice Mints the token to the specified address.
    /// @param to The address to mint the token to
    /// @param amount The amount of token to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @inheritdoc ERC20
    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }
}
