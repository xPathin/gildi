// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import './ILBMagicSeaRouter.sol';

/// @title ILBMagicSeaQuoter
/// @notice Minimal interface for the LBMagicSea Quoter.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
interface ILBMagicSeaQuoter {
    /// @notice The quote struct returned by the quoter
    /// @param route The address array of the token to go through
    /// @param pairs The address array of the pairs to go through
    /// @param binSteps The bin step to use for each pair
    /// @param versions The version to use for each pair
    /// @param amounts The amounts of every step of the swap
    /// @param virtualAmountsWithoutSlippage The virtual amounts of every step of the swap without slippage
    /// @param fees The fees to pay for every step of the swap
    struct Quote {
        address[] route;
        address[] pairs;
        uint256[] binSteps;
        ILBMagicSeaRouter.Version[] versions;
        uint128[] amounts;
        uint128[] virtualAmountsWithoutSlippage;
        uint128[] fees;
    }

    /// @notice This error is thrown when the length of the route is invalid
    error LBQuoter_InvalidLength();

    /// @notice Finds the best path given a list of tokens and the input amount wanted from the swap
    /// @param route List of the tokens to go through
    /// @param amountIn Swap amount in
    /// @return quote The Quote structure containing the necessary element to perform the swap
    function findBestPathFromAmountIn(
        address[] calldata route,
        uint128 amountIn
    ) external view returns (Quote memory quote);

    /// @notice Finds the best path given a list of tokens and the output amount wanted from the swap
    /// @param route List of the tokens to go through
    /// @param amountOut Swap amount out
    /// @return quote The Quote structure containing the necessary element to perform the swap
    function findBestPathFromAmountOut(
        address[] calldata route,
        uint128 amountOut
    ) external view returns (Quote memory quote);
}
