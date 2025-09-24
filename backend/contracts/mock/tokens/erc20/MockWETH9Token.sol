// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import {MockERC20Token, ERC20} from './MockERC20Token.sol';
import {IWNative} from '../../../interfaces/external/IWNative.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/// @title MockWETH9Token
/// @notice Mock implementation of the WETH9 token for testing and development purposes
/// @dev Provides wrapped ETH functionality with deposit/withdraw capabilities and reentrancy protection
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract MockWETH9Token is IWNative, MockERC20Token, ReentrancyGuard {
    /// @dev Optional override for the ERC20 name returned by `name()` when non-empty.
    string private overrideNameValue;
    /// @dev Optional override for the ERC20 symbol returned by `symbol()` when non-empty.
    string private overrideSymbolValue;

    /// @notice Role permitted to administer contract-level settings (e.g., name/symbol overrides).
    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256('CONTRACT_ADMIN_ROLE');

    /// @dev Reverts when ETH transfer via withdraw fails
    error EthTransferFailed();

    /// @dev Reverts when no name is set
    error EmptyName();

    /// @dev Reverts when no symbol is set
    error EmptySymbol();

    /// @notice Initialize the MockWETH9Token contract
    /// @dev Sets up the ERC20 token with name "Mock WETH9", symbol "mWETH9", and 18 decimals
    /// @param _initialDefaultAdmin The address that will have admin privileges for the token
    /// @param _initialContractAdmin The address that will have admin privileges for the contract
    /// @param _overrideName The name of the token
    /// @param _overrideSymbol The symbol of the token
    constructor(
        address _initialDefaultAdmin,
        address _initialContractAdmin,
        string memory _overrideName,
        string memory _overrideSymbol
    ) MockERC20Token('Mock WETH9', 'mWETH9', 18, _initialDefaultAdmin) {
        _grantRole(CONTRACT_ADMIN_ROLE, _initialContractAdmin);

        overrideNameValue = _overrideName;
        overrideSymbolValue = _overrideSymbol;
    }

    /// @notice Emitted when ETH is deposited and WETH tokens are minted
    /// @param dst The address receiving the wrapped tokens
    /// @param wad The amount of ETH deposited and tokens minted
    event Deposit(address indexed dst, uint wad);

    /// @notice Emitted when WETH tokens are burned and ETH is withdrawn
    /// @param src The address withdrawing the ETH
    /// @param wad The amount of tokens burned and ETH withdrawn
    event Withdrawal(address indexed src, uint wad);

    /// @notice Emitted when the token name override is updated
    /// @param previousName The previously observed token name
    /// @param newName The new token name
    event CustomNameUpdated(string previousName, string newName);

    /// @notice Emitted when the token symbol override is updated
    /// @param previousSymbol The previously observed token symbol
    /// @param newSymbol The new token symbol
    event CustomSymbolUpdated(string previousSymbol, string newSymbol);

    /// @inheritdoc IWNative
    function deposit() public payable override nonReentrant {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IWNative
    function withdraw(uint256 _amount) public override nonReentrant {
        _burn(msg.sender, _amount);
        (bool ok, ) = msg.sender.call{value: _amount}('');
        if (!ok) {
            revert EthTransferFailed();
        }
        emit Withdrawal(msg.sender, _amount);
    }

    /// @notice Sets a new token name override.
    /// @param _name The new token name to expose via `name()`.
    function setCustomName(string memory _name) external onlyRole(CONTRACT_ADMIN_ROLE) {
        if (bytes(_name).length == 0) {
            revert EmptyName();
        }
        string memory previous = bytes(overrideNameValue).length > 0 ? overrideNameValue : super.name();
        overrideNameValue = _name;
        emit CustomNameUpdated(previous, _name);
    }

    /// @notice Sets a new token symbol override.
    /// @param _symbol The new token symbol to expose via `symbol()`.
    function setCustomSymbol(string memory _symbol) external onlyRole(CONTRACT_ADMIN_ROLE) {
        if (bytes(_symbol).length == 0) {
            revert EmptySymbol();
        }
        string memory previous = bytes(overrideSymbolValue).length > 0 ? overrideSymbolValue : super.symbol();
        overrideSymbolValue = _symbol;
        emit CustomSymbolUpdated(previous, _symbol);
    }

    /// @notice Clears the custom token name override and restores the base ERC20 name
    /// @dev Sets `overrideNameValue` to empty so `name()` falls back to `super.name()`
    function clearCustomName() external onlyRole(CONTRACT_ADMIN_ROLE) {
        overrideNameValue = '';
    }

    /// @notice Clears the custom token symbol override and restores the base ERC20 symbol
    /// @dev Sets `overrideSymbolValue` to empty so `symbol()` falls back to `super.symbol()`
    function clearCustomSymbol() external onlyRole(CONTRACT_ADMIN_ROLE) {
        overrideSymbolValue = '';
    }

    /// @inheritdoc ERC20
    function name() public view override returns (string memory) {
        return bytes(overrideNameValue).length > 0 ? overrideNameValue : super.name();
    }

    /// @inheritdoc ERC20
    function symbol() public view override returns (string memory) {
        return bytes(overrideSymbolValue).length > 0 ? overrideSymbolValue : super.symbol();
    }

    /// @notice Receive function that automatically deposits ETH when sent directly to contract
    /// @dev Calls the deposit function when ETH is sent without data
    receive() external payable {
        deposit();
    }

    /// @notice Fallback function that automatically deposits ETH when sent directly to contract
    /// @dev Calls the deposit function when ETH is sent with data
    fallback() external payable {
        deposit();
    }
}
