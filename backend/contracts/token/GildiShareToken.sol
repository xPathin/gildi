// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableMap.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import '../interfaces/token/IGildiToken.sol';

/// @title Gilde Company Share Token
/// @notice ERC1155 token that represents company shares.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract GildiShareToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155SupplyUpgradeable,
    IGildiToken
{
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice A role reserved for the Gildi Manager smart contract that allows for the burning of tokens.
    bytes32 public constant GILDI_MANAGER_ROLE = keccak256('GILDI_MANAGER_ROLE');
    /// @notice A role that allows for setting the token name, symbol, and URI.
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @dev The name of the token.
    string private tokenName;
    /// @dev The symbol of the token.
    string private tokenSymbol;
    /// @dev Replace TokenUri {id} with the token ID.
    bool private tokenUriReplaceId;

    /// @dev A mapping of token balances of an address by token ID.
    mapping(uint256 => EnumerableMap.AddressToUintMap) private _tokenBalances;
    /// @dev A mapping of owned tokens by address.
    mapping(address => EnumerableSet.UintSet) private _ownedTokens;

    /// @dev Emitted when the token name changed.
    event NameChanged(string newName);
    /// @dev Emitted when the token symbol changed.
    event SymbolChanged(string newSymbol);
    /// @dev Emitted when the token URI changed.
    event URIChanged(string newURI);
    /// @dev Emitted when wether to replace the token URI {id} placeholder changed.
    event TokenUriReplaceIdChanged(bool replaceId);

    error InvalidMintBatch();
    error InvalidId();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract.
    /// @param _defaultAdmin The default admin of the contract.
    /// @param _initialAdmin The initial admin of the contract.
    /// @param _baseUri The base URI of the token.
    function initialize(address _defaultAdmin, address _initialAdmin, string memory _baseUri) public initializer {
        __ERC1155_init(_baseUri);
        __AccessControl_init();
        __ERC1155Pausable_init();
        __ERC1155Supply_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        if (_initialAdmin != address(0)) {
            _grantRole(ADMIN_ROLE, _initialAdmin);
        }

        tokenName = 'Gildi Share Token';
        tokenSymbol = 'GILDI';

        tokenUriReplaceId = true;
    }

    /// @notice Sets the URI of the token.
    /// @param _newUri The new URI.
    function setURI(string memory _newUri) public onlyRole(ADMIN_ROLE) {
        _setURI(_newUri);
        emit URIChanged(_newUri);
    }

    /// @notice Sets wether to replace the token URI {id} placeholder.
    /// @param _replaceId Wether to replace the token URI {id} placeholder.
    function setTokenUriReplaceId(bool _replaceId) public onlyRole(ADMIN_ROLE) {
        tokenUriReplaceId = _replaceId;
        emit TokenUriReplaceIdChanged(_replaceId);
    }

    /// @inheritdoc IGildiToken
    function pause() public override onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @inheritdoc IGildiToken
    function unpause() public override onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @inheritdoc IGildiToken
    function name() external view override returns (string memory) {
        return tokenName;
    }

    /// @inheritdoc IGildiToken
    function symbol() external view override returns (string memory) {
        return tokenSymbol;
    }

    /// @notice Set the name of the token.
    /// @param _name The new name of the token.
    function setName(string memory _name) external onlyRole(ADMIN_ROLE) {
        tokenName = _name;
        emit NameChanged(_name);
    }

    /// @notice Set the symbol of the token.
    /// @param _symbol The new symbol of the token.
    function setSymbol(string memory _symbol) external onlyRole(ADMIN_ROLE) {
        tokenSymbol = _symbol;
        emit SymbolChanged(_symbol);
    }

    /// @inheritdoc IGildiToken
    function totalSupply(uint256 _id) public view override(IGildiToken, ERC1155SupplyUpgradeable) returns (uint256) {
        return super.totalSupply(_id);
    }

    /// @inheritdoc IGildiToken
    function totalSupply() public view override(IGildiToken, ERC1155SupplyUpgradeable) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IGildiToken
    function exists(uint256 _id) public view override(IGildiToken, ERC1155SupplyUpgradeable) returns (bool) {
        return super.exists(_id);
    }

    /// @inheritdoc IGildiToken
    function mint(
        address _account,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override onlyRole(GILDI_MANAGER_ROLE) whenNotPaused {
        if (_id == 0) {
            revert InvalidId();
        }
        _mint(_account, _id, _amount, _data);
    }

    /// @inheritdoc IGildiToken
    function mintBatch(
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external onlyRole(GILDI_MANAGER_ROLE) whenNotPaused {
        for (uint256 i = 0; i < _ids.length; i++) {
            if (_ids[i] == 0) {
                revert InvalidId();
            }
        }
        _mintBatch(_to, _ids, _amounts, _data);
    }

    /// @inheritdoc IGildiToken
    function mintBatchMany(
        MintBatch[] calldata _mintBatches
    ) external override onlyRole(GILDI_MANAGER_ROLE) whenNotPaused {
        for (uint256 i = 0; i < _mintBatches.length; i++) {
            MintBatch memory mintBatchEntry = _mintBatches[i];
            if (mintBatchEntry.ids.length != mintBatchEntry.amounts.length) {
                revert InvalidMintBatch();
            }
            for (uint256 j = 0; j < mintBatchEntry.ids.length; j++) {
                if (mintBatchEntry.ids[j] == 0) {
                    revert InvalidId();
                }
            }
            _mintBatch(mintBatchEntry.to, mintBatchEntry.ids, mintBatchEntry.amounts, mintBatchEntry.data);
        }
    }

    /// @inheritdoc IGildiToken
    function burn(
        address _account,
        uint256 _id,
        uint256 _value
    ) external override whenNotPaused onlyRole(GILDI_MANAGER_ROLE) {
        _burn(_account, _id, _value);
    }

    /// @inheritdoc IGildiToken
    function burnBatch(
        address _account,
        uint256[] calldata _ids,
        uint256[] calldata _values
    ) external override whenNotPaused onlyRole(GILDI_MANAGER_ROLE) {
        _burnBatch(_account, _ids, _values);
    }

    /// @inheritdoc IGildiToken
    function burnAllById(uint256 _id) external override onlyRole(GILDI_MANAGER_ROLE) whenNotPaused {
        // Burn all tokens of a specific ID from all accounts.
        address[] memory accounts = _tokenBalances[_id].keys();

        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 balance = _tokenBalances[_id].get(accounts[i]);
            _burn(accounts[i], _id, balance);
        }
    }

    /// @inheritdoc IGildiToken
    function tokensOfOwner(address _account) external view override returns (TokenBalance[] memory ownedTokens) {
        uint256[] memory tokensOwned = _ownedTokens[_account].values();
        ownedTokens = new TokenBalance[](tokensOwned.length);

        for (uint256 i = 0; i < tokensOwned.length; i++) {
            // Get balance via _tokenBalances mapping
            uint256 balance = _tokenBalances[tokensOwned[i]].get(_account);
            ownedTokens[i] = TokenBalance(tokensOwned[i], balance);
        }
    }

    /// @inheritdoc ERC1155Upgradeable
    function uri(uint256 _tokenId) public view override returns (string memory) {
        string memory baseURI = super.uri(_tokenId); // Get the base URI
        string memory tokenIDStr = Strings.toString(_tokenId);

        // Check if the base URI contains the "{id}" placeholder
        if (bytes(baseURI).length > 0) {
            bytes memory toReplace = '{id}';
            bytes memory baseURIBytes = bytes(baseURI);
            bytes memory toReplaceBytes = bytes(toReplace);

            // Search for the "{id}" substring
            bool found = false;
            for (uint256 i = 0; i < baseURIBytes.length - toReplaceBytes.length + 1; i++) {
                bool xmatch = true;
                for (uint256 j = 0; j < toReplaceBytes.length; j++) {
                    if (baseURIBytes[i + j] != toReplaceBytes[j]) {
                        xmatch = false;
                        break;
                    }
                }

                // If "{id}" is found and replace is enabled, replace it with the token ID
                if (xmatch) {
                    found = true;
                    if (tokenUriReplaceId) {
                        return
                            string(
                                abi.encodePacked(
                                    _substring(baseURI, 0, i),
                                    tokenIDStr,
                                    _substring(baseURI, i + toReplaceBytes.length, baseURIBytes.length)
                                )
                            );
                    }
                }
            }

            // If "{id}" is not found, append '/' if necessary and then the token ID
            if (!found) {
                if (baseURIBytes[baseURIBytes.length - 1] != '/') {
                    return string(abi.encodePacked(baseURI, '/', tokenIDStr));
                }
                return string(abi.encodePacked(baseURI, tokenIDStr));
            }
        }

        return baseURI; // Return the base URI if no placeholder is found
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(ERC1155Upgradeable, AccessControlUpgradeable, IERC165) returns (bool) {
        return super.supportsInterface(_interfaceId) || _interfaceId == type(IGildiToken).interfaceId;
    }

    /// @inheritdoc ERC1155Upgradeable
    function _update(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values
    ) internal override(ERC1155Upgradeable, ERC1155PausableUpgradeable, ERC1155SupplyUpgradeable) {
        super._update(_from, _to, _ids, _values);

        if (_to == address(0) && _from != address(0)) {
            _recordDebit(_from, _ids, _values);
        }

        if (_from == address(0) && _to != address(0)) {
            _recordCredit(_to, _ids, _values);
        }

        if (_to != address(0) && _from != address(0)) {
            _recordDebit(_from, _ids, _values);
            _recordCredit(_to, _ids, _values);
        }
    }

    function _substring(string memory _str, uint _startIndex, uint _endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(_endIndex - _startIndex);
        for (uint i = _startIndex; i < _endIndex; i++) {
            result[i - _startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _recordCredit(address _account, uint256[] memory _ids, uint256[] memory _values) private {
        for (uint256 i = 0; i < _ids.length; i++) {
            if (!_tokenBalances[_ids[i]].contains(_account)) {
                _tokenBalances[_ids[i]].set(_account, 0);
            }
            _tokenBalances[_ids[i]].set(_account, _tokenBalances[_ids[i]].get(_account) + _values[i]);
            _ownedTokens[_account].add(_ids[i]);
        }
    }

    function _recordDebit(address _account, uint256[] memory _ids, uint256[] memory _values) private {
        for (uint256 i = 0; i < _ids.length; i++) {
            _tokenBalances[_ids[i]].set(_account, _tokenBalances[_ids[i]].get(_account) - _values[i]);
            if (_tokenBalances[_ids[i]].get(_account) == 0) {
                _ownedTokens[_account].remove(_ids[i]);
            }
        }
    }
}
