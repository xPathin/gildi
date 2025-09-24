// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

/// @title IGildiToken
/// @notice Interface for tokens of the Gildi platform.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
interface IGildiToken is IERC1155 {
    /// @notice The balance of a specific token for an address.
    struct TokenBalance {
        /// @notice The token ID.
        uint256 tokenId;
        /// @notice The balance of the token.
        uint256 balance;
    }

    struct MintBatch {
        address to;
        uint256[] ids;
        uint256[] amounts;
        bytes data;
    }

    /// @notice Pause the contract.
    function pause() external;

    /// @notice Unpause the contract.
    function unpause() external;

    /// @notice The name of the token.
    function name() external view returns (string memory);

    /// @notice The symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Fetch the total supply of a specific token.
    /// @param _id The ID of the token.
    /// @return The total supply of the token.
    function totalSupply(uint256 _id) external view returns (uint256);

    /// @notice Fetch the total supply of all tokens.
    /// @return The total supply of all tokens.
    function totalSupply() external view returns (uint256);

    /// @notice Check if a token exists.
    /// @param _id The ID of the token.
    /// @return True if the token exists, false otherwise.
    function exists(uint256 _id) external view returns (bool);

    /// @notice Mint a specific amount of a token.
    /// @param _account The address to mint the token to.
    /// @param _id The ID of the token.
    /// @param _amount The amount of the token to mint.
    /// @param _data The data to pass to the receiver.
    function mint(address _account, uint256 _id, uint256 _amount, bytes calldata _data) external;

    /// @notice Batch mint a specific amount of tokens.
    /// @param _to The address to mint the tokens to.
    /// @param _ids The IDs of the tokens.
    /// @param _amounts The amounts of the tokens to mint.
    /// @param _data The data to pass to the receiver.
    function mintBatch(
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external;

    /// @notice Batch mint to many addresses.
    /// @param _mintBatches The mint batches.
    function mintBatchMany(MintBatch[] calldata _mintBatches) external;

    /// @notice Burn a specific amount of a token.
    /// @param _account The address to burn the token from.
    /// @param _id The ID of the token.
    /// @param _value The amount of the token to burn.
    function burn(address _account, uint256 _id, uint256 _value) external;

    /// @notice Burn a specific amount of a token in a batch.
    /// @param _account The address to burn the token from.
    /// @param _ids The IDs of the tokens.
    /// @param _values The amounts of the tokens to burn.
    function burnBatch(address _account, uint256[] calldata _ids, uint256[] calldata _values) external;

    /// @notice Burn all tokens of a specific ID.
    /// @param _id The ID of the token.
    function burnAllById(uint256 _id) external;

    /// @notice Fetch all tokens and their balances of an owner.
    /// @param _account The address of the owner.
    function tokensOfOwner(address _account) external view returns (TokenBalance[] memory ownedTokens);
}
