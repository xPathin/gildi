// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '../MockERC20Token.sol';

/// @title MockTokenFaucet
/// @dev For testing purposes only.
/// @notice This contract is a faucet for ERC20 mock tokens.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract MockTokenFaucet is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address[] private faucetTokens;
    mapping(address => uint256) private faucetTokenBaseAmount;
    mapping(address => bool) private isFaucetToken;

    uint256 private mintCooldown;
    uint256 private receiveCooldown;

    mapping(address => mapping(address => uint256)) private lastMinted;
    mapping(address => mapping(address => uint256)) private lastReceived;

    error TokenNotFaucetToken();
    error ContractNotMinter();
    error MintCooldownNotExpired();
    error ReceiveCooldownNotExpired();
    error BadRequest();

    event FaucetTokenSet(address token, uint256 baseAmount);
    event FaucetTokenRemoved(address token);
    event MintCooldownSet(uint256 cooldown);
    event ReceiveCooldownSet(uint256 cooldown);
    event FaucetSent(address token, address receiver, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _mintCooldown The cooldown period for minting in seconds
    /// @param _receiveCooldown The cooldown period for receiving in seconds
    function initialize(address _initialOwner, uint256 _mintCooldown, uint256 _receiveCooldown) public initializer {
        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        mintCooldown = _mintCooldown;
        receiveCooldown = _receiveCooldown;
    }

    /// @notice Request tokens from the faucet
    /// @param _tokenAddress The address of the token to mint
    /// @param _receiver The address that will receive the tokens
    /// @param _mintAmount The amount of tokens to mint
    function requestTokens(
        address[] calldata _tokenAddress,
        address _receiver,
        uint256[] calldata _mintAmount
    ) external nonReentrant {
        if (_tokenAddress.length != _mintAmount.length) {
            revert BadRequest();
        }

        for (uint256 i = 0; i < _tokenAddress.length; i++) {
            _requestFaucetToken(_tokenAddress[i], _receiver, _mintAmount[i]);
        }
    }

    /// @notice Request a single token from the faucet
    /// @param _tokenAddress The address of the token to mint
    /// @param _receiver The address that will receive the tokens
    /// @param _mintAmount The amount of tokens to mint
    function requestToken(address _tokenAddress, address _receiver, uint256 _mintAmount) external nonReentrant {
        _requestFaucetToken(_tokenAddress, _receiver, _mintAmount);
    }

    /// @notice Request all tokens from the faucet
    /// @param _receiver The address that will receive the tokens
    function requestAllTokens(address _receiver) external nonReentrant {
        for (uint256 i = 0; i < faucetTokens.length; i++) {
            _requestFaucetToken(faucetTokens[i], _receiver, faucetTokenBaseAmount[faucetTokens[i]]);
        }
    }

    /// @notice Set a token as a faucet token with a base amount
    /// @param _tokenAddress The address of the token
    /// @param _baseAmount The base amount for the token
    function setFaucetToken(address _tokenAddress, uint256 _baseAmount) external onlyOwner {
        MockERC20Token token = MockERC20Token(_tokenAddress);
        if (!token.hasRole(token.MINTER_ROLE(), address(this))) {
            revert ContractNotMinter();
        }

        if (!isFaucetToken[_tokenAddress]) {
            faucetTokens.push(_tokenAddress);
            isFaucetToken[_tokenAddress] = true;
        }

        faucetTokenBaseAmount[_tokenAddress] = _baseAmount;

        emit FaucetTokenSet(_tokenAddress, _baseAmount);
    }

    /// @notice Remove a token from the faucet
    /// @param _token The address of the token to remove
    function removeFaucetToken(address _token) external onlyOwner {
        if (!isFaucetToken[_token]) {
            revert TokenNotFaucetToken();
        }

        isFaucetToken[_token] = false;
        faucetTokenBaseAmount[_token] = 0;

        for (uint256 i = 0; i < faucetTokens.length; i++) {
            if (faucetTokens[i] == _token) {
                faucetTokens[i] = faucetTokens[faucetTokens.length - 1];
                faucetTokens.pop();
                break;
            }
        }

        emit FaucetTokenRemoved(_token);
    }

    /// @notice Set the mint cooldown period
    /// @param _cooldown The new mint cooldown period in seconds
    function setMintCooldown(uint256 _cooldown) external onlyOwner {
        mintCooldown = _cooldown;

        emit MintCooldownSet(_cooldown);
    }

    /// @notice Set the receive cooldown period
    /// @param _cooldown The new receive cooldown period in seconds
    function setReceiveCooldown(uint256 _cooldown) external onlyOwner {
        receiveCooldown = _cooldown;

        emit ReceiveCooldownSet(_cooldown);
    }

    /// @notice Check if a token is a faucet token
    /// @param _token The address of the token
    function getIsFaucetToken(address _token) external view returns (bool) {
        return isFaucetToken[_token];
    }

    /// @notice Get the base amounts for all faucet tokens
    /// @return tokenAddresses An array of faucet token addresses
    /// @return tokenAmounts An array of base amounts for the faucet tokens
    function getFaucetTokenBaseAmounts()
        external
        view
        returns (address[] memory tokenAddresses, uint256[] memory tokenAmounts)
    {
        tokenAddresses = new address[](faucetTokens.length);
        tokenAmounts = new uint256[](faucetTokens.length);

        for (uint256 i = 0; i < faucetTokens.length; i++) {
            tokenAddresses[i] = faucetTokens[i];
            tokenAmounts[i] = faucetTokenBaseAmount[faucetTokens[i]];
        }
    }

    /// @notice Get the list of faucet tokens
    /// @return An array of faucet token addresses
    function getFaucetTokens() external view returns (address[] memory) {
        return faucetTokens;
    }

    /// @notice Get the base amount for a faucet token
    /// @param _tokenAddress The address of the token
    /// @return The base amount for the token
    function getFaucetTokenBaseAmount(address _tokenAddress) external view returns (uint256) {
        return faucetTokenBaseAmount[_tokenAddress];
    }

    /// @notice Get the last mint timestamp for a user and token
    /// @param user The address of the user
    /// @param token The address of the token
    /// @return The last mint timestamp
    function getLastMinted(address user, address token) external view returns (uint256) {
        return lastMinted[user][token];
    }

    /// @notice Get the last receive timestamp for a user and token
    /// @param user The address of the user
    /// @param token The address of the token
    /// @return The last receive timestamp
    function getLastReceived(address user, address token) external view returns (uint256) {
        return lastReceived[user][token];
    }

    /// @notice Get the next mint timestamp for a token
    /// @param _tokenAddress The address of the token
    /// @param _caller The address of the caller
    /// @param _receiver The address of the receiver
    /// @return The timestamp of the next mint
    function getNextMintTimestamp(
        address _tokenAddress,
        address _caller,
        address _receiver
    ) external view returns (uint256) {
        uint256 callerTokenLastMinted = lastMinted[_caller][_tokenAddress];
        uint256 receiverTokenLastReceived = lastReceived[_receiver][_tokenAddress];

        if (callerTokenLastMinted > receiverTokenLastReceived) {
            return callerTokenLastMinted + mintCooldown;
        } else {
            return receiverTokenLastReceived + receiveCooldown;
        }
    }

    /// @dev Internal function to request a token from the faucet
    /// @param _tokenAddress The address of the token to mint
    /// @param _receiver The address that will receive the tokens
    /// @param _mintAmount The amount of tokens to mint
    function _requestFaucetToken(address _tokenAddress, address _receiver, uint256 _mintAmount) internal {
        if (!isFaucetToken[_tokenAddress]) {
            revert TokenNotFaucetToken();
        }

        if (block.timestamp - lastMinted[msg.sender][_tokenAddress] < mintCooldown) {
            revert MintCooldownNotExpired();
        }

        if (block.timestamp - lastReceived[_receiver][_tokenAddress] < receiveCooldown) {
            revert ReceiveCooldownNotExpired();
        }

        MockERC20Token token = MockERC20Token(_tokenAddress);
        if (!token.hasRole(token.MINTER_ROLE(), address(this))) {
            revert ContractNotMinter();
        }

        if (_mintAmount > faucetTokenBaseAmount[_tokenAddress]) {
            _mintAmount = faucetTokenBaseAmount[_tokenAddress];
        }

        if (_mintAmount == 0) {
            _mintAmount = faucetTokenBaseAmount[_tokenAddress];
        }

        // If balance is already at faucetTokenBaseAmount, mint only 10% of the base amount
        if (token.balanceOf(_receiver) >= faucetTokenBaseAmount[_tokenAddress]) {
            _mintAmount = faucetTokenBaseAmount[_tokenAddress] / 10;
        }

        token.mint(_receiver, _mintAmount);

        // Update cooldown timestamps
        lastMinted[msg.sender][_tokenAddress] = block.timestamp;
        lastReceived[_receiver][_tokenAddress] = block.timestamp;

        emit FaucetSent(_tokenAddress, _receiver, _mintAmount);
    }
}
