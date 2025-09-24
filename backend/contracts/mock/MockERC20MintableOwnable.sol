// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

contract MockERC20MintableOwnable is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    uint8 private tokenDecimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) Ownable(_msgSender()) ERC20Permit(_name) {
        if (_decimals > 18 || _decimals == 0) {
            _decimals = 18;
        }

        tokenDecimals = _decimals;
    }

    function mint(address _to, uint256 _amount) public virtual onlyOwner {
        _mint(_to, _amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}
