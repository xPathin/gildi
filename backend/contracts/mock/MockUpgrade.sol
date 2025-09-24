// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

abstract contract MockUpgrade {
    bool private newFunctionValue;

    /// @dev This function is used to test the upgradeability of the contract.
    /// @return True if the function is called, false otherwise.
    function newFunctionGetter() external view returns (bool) {
        return newFunctionValue;
    }

    /// @dev This function is used to test the upgradeability of the contract.
    /// @param _newFunctionValue The new value for the function.
    function newFunctionSetter(bool _newFunctionValue) external {
        newFunctionValue = _newFunctionValue;
    }

    /// @dev Returns true to indicate this is an upgraded contract
    /// @return Boolean indicating upgrade status
    function isUpgraded() public pure returns (bool) {
        return true;
    }
}
