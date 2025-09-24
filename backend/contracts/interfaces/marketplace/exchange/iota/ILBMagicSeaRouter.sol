// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title ILBMagicSeaRouter
/// @notice Minimal interface for the LBMagicSea Router.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
interface ILBMagicSeaRouter {
    /// @notice This enum represents the version of the pair requested.
    /// @dev V1: Joe V1 pair, V2: LB pair V2. Also called legacyPair, V2_1: LB pair V2.1 (current version)
    enum Version {
        V1,
        V2,
        V2_1
    }

    /// @notice The liquidity parameters
    /// @param tokenX The address of token X
    /// @param tokenY The address of token Y
    /// @param binStep The bin step of the pair
    /// @param amountX The amount to send of token X
    /// @param amountY The amount to send of token Y
    /// @param amountXMin The min amount of token X added to liquidity
    /// @param amountYMin The min amount of token Y added to liquidity
    /// @param activeIdDesired The active id that user wants to add liquidity from
    /// @param idSlippage The number of id that are allowed to slip
    /// @param deltaIds The list of delta ids to add liquidity (`deltaId = activeId - desiredId`)
    /// @param distributionX The distribution of tokenX with sum(distributionX) = 1e18 (100%) or 0 (0%)
    /// @param distributionY The distribution of tokenY with sum(distributionY) = 1e18 (100%) or 0 (0%)
    /// @param to The address of the recipient
    /// @param refundTo The address of the recipient of the refunded tokens if too much tokens are sent
    /// @param deadline The deadline of the transaction
    struct LiquidityParameters {
        IERC20 tokenX;
        IERC20 tokenY;
        uint256 binStep;
        uint256 amountX;
        uint256 amountY;
        uint256 amountXMin;
        uint256 amountYMin;
        uint256 activeIdDesired;
        uint256 idSlippage;
        int256[] deltaIds;
        uint256[] distributionX;
        uint256[] distributionY;
        address to;
        address refundTo;
        uint256 deadline;
    }

    /// @notice The path parameters
    /// @param pairBinSteps The list of bin steps of the pairs to go through
    /// @param versions The list of versions of the pairs to go through
    /// @param tokenPath The list of tokens in the path to go through
    struct Path {
        uint256[] pairBinSteps;
        Version[] versions;
        IERC20[] tokenPath;
    }

    /// @param amountIn The exact amount of input tokens to send
    /// @param amountOutMin The minimum amount of output tokens to receive; reverts if not met
    /// @param path Defines the swap path with pairs' bin steps, versions, and token sequence
    /// @param to The recipient address of the output tokens
    /// @param deadline The timestamp by which the transaction must be executed
    /// @return amountOut The actual amount of output tokens received
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice Swaps tokens to receive an exact amount of output tokens along a specified path, using a maximum input limit
    /// @dev The caller must approve the router to spend up to `amountInMax` of the first token in the path
    /// @param amountOut The exact amount of output tokens to receive
    /// @param amountInMax The maximum allowable input tokens to spend; reverts if exceeded
    /// @param path Defines the swap path with pairs' bin steps, versions, and token sequence
    /// @param to The recipient address of the output tokens
    /// @param deadline The timestamp by which the transaction must be executed
    /// @return amountsIn An array of input amounts used at each swap step in the path
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amountsIn);
}
