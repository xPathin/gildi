// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/utils/structs/EnumerableMap.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';

import '../interfaces/manager/IGildiManager.sol';
import '../interfaces/token/IGildiToken.sol';
import './GildiManagerOwnershipStorage.sol';

/// @title GildiManager
/// @notice A contract which tracks ownership of ERC1155 RWAs and allows for the transfer of ownership.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract GildiManager is
    Initializable,
    AccessControlUpgradeable,
    ERC1155HolderUpgradeable,
    IGildiManager,
    ReentrancyGuardUpgradeable
{
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice A role that allows the contract to manage releases.
    bytes32 public constant RELEASE_MANAGER_ROLE = keccak256('RELEASE_MANAGER_ROLE');
    /// @notice A role for marketplace contracts.
    bytes32 public constant MARKETPLACE_ROLE = keccak256('MARKETPLACE_ROLE');
    /// @notice A role for the admin.
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    enum Roles {
        RELEASE_MANAGER,
        MARKETPLACE,
        ADMIN
    }

    /// @notice The Gildi token contract.
    IGildiToken public gildiToken;
    /// @notice An array of releases.
    uint256[] public rwaReleaseIds;

    /// @notice Whether a release exists.
    mapping(uint256 => bool) private existingReleases;

    /// @notice The RWA releases.
    mapping(uint256 => IGildiManager.RWARelease) public rwaReleases;

    /// @notice The owners of a token.
    mapping(uint256 => address[]) private tokenOwners;

    /// @notice If a user is the owner of a token.
    mapping(address => mapping(uint256 => bool)) private isTokenOwner;

    /// @notice How many of a token is owned by a user.
    mapping(uint256 => mapping(address => TokenBalance)) private userTokenBalance;

    /// @notice Mapping of ownership storages.
    mapping(uint256 => GildiManagerOwnershipStorage) public releaseOwnershipStorages;

    /// @notice Throws if the caller does not have any of the required roles.
    error AccessControlUnauthorizedAccountAny(address account, bytes32[] roles);
    error ReleaseAlreadyExists(uint256 tokenId);
    error AmountMustBeGreaterThanZero();
    error ReleaseDoesNotExist(uint256 tokenId);
    error SharesMustNotBeEmpty();
    error TooManyShares(uint256 maxShares);
    error ReleaseIsDeleting(uint256 tokenId);
    error InsufficientUnassignedShares(uint256 unassignedShares, uint256 requiredAmount);
    error WrongInitialSaleState(bool expectedState, bool actualState);
    error InvalidBatchSize(uint256 batchSizeMin, uint256 batchSizeMax);
    error NotFullyAssignedShares();
    error InsufficientAvailableBalance(uint256 tokenId, address account);
    error ReleaseTokenAlreadyExists(uint256 tokenId);
    error InvalidLockState(bool expectedState, bool actualState);
    error AddressZeroNotAllowed();

    event ReleaseUnlocked(uint256 indexed releaseId);
    event ReleaseCreated(uint256 indexed releaseId, uint256 amount);
    event ShareAssigned(uint256 indexed releaseId, address indexed user, uint256 shares);
    event SharesAssigned(uint256 indexed releaseId, uint256 totalShares);
    event InitialSaleStarted(uint256 indexed releaseId);
    event InitialSaleEnded(uint256 indexed releaseId);
    event ReleaseMarkedForDeletion(uint256 indexed releaseId);
    event ReleaseBatchDeleted(uint256 indexed releaseId, uint256 deletedShares, uint256 remainingOwners);
    event ReleaseDeleted(uint256 indexed releaseId);
    event TokenDeposited(uint256 indexed tokenId, address indexed account, uint256 amount);
    event TokenWithdrawn(uint256 indexed tokenId, address indexed account, uint256 amount);
    event TokenTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);
    event TokenUnlocked(uint256 indexed tokenId, address indexed account, uint256 amount);
    event TokenLocked(uint256 indexed tokenId, address indexed account, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract.
    /// @param _defaultAdmin The default admin.
    /// @param _initialAdmin The initial admin.
    /// @param _initialReleaseManager The initial release manager.
    /// @param _rwaToken The RWA token contract.
    function initialize(
        address _defaultAdmin,
        address _initialAdmin,
        address _initialReleaseManager,
        IGildiToken _rwaToken
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        if (_initialAdmin != address(0)) {
            _grantRole(ADMIN_ROLE, _initialAdmin);
        }
        if (_initialReleaseManager != address(0)) {
            _grantRole(RELEASE_MANAGER_ROLE, _initialReleaseManager);
        }

        gildiToken = _rwaToken;
    }

    /// @inheritdoc IGildiManager
    function unlockRelease(
        uint256 _releaseId
    ) public override whenLocked(_releaseId) onlyRoleAny(_rolesReleaseManagerMarketplace()) {
        RWARelease storage release = rwaReleases[_releaseId];

        if (release.unassignedShares != 0) {
            revert NotFullyAssignedShares();
        }
        if (release.deleting) {
            revert ReleaseIsDeleting(_releaseId);
        }
        if (release.inInitialSale) {
            revert WrongInitialSaleState(!release.inInitialSale, release.inInitialSale);
        }

        release.locked = false;
        release.unlockedAt = block.timestamp;

        emit ReleaseUnlocked(_releaseId);
    }

    /// @inheritdoc IGildiManager
    function getAllReleaseIds() external view returns (uint256[] memory) {
        return rwaReleaseIds;
    }

    /// @inheritdoc IGildiManager
    function releaseExists(uint256 _releaseId) public view override returns (bool) {
        return existingReleases[_releaseId];
    }

    /// @inheritdoc IGildiManager
    function getAvailableBalance(uint256 _tokenId, address _account) public view override returns (uint256) {
        TokenBalance memory balance = userTokenBalance[_tokenId][_account];
        return balance.amount - balance.lockedAmount;
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(AccessControlUpgradeable, ERC1155HolderUpgradeable, IERC165) returns (bool) {
        return super.supportsInterface(_interfaceId) || _interfaceId == type(IGildiManager).interfaceId;
    }

    /// @inheritdoc IGildiManager
    function createNewRelease(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _ownershipTrackingTimePeriod
    ) external override onlyRole(RELEASE_MANAGER_ROLE) {
        if (_ownershipTrackingTimePeriod == 0) {
            _ownershipTrackingTimePeriod = 30 minutes;
        }

        if (releaseExists(_tokenId) || gildiToken.exists(_tokenId)) {
            revert ReleaseAlreadyExists(_tokenId);
        }

        if (_amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        gildiToken.mint(address(this), _tokenId, _amount, '');

        rwaReleases[_tokenId] = RWARelease(_tokenId, true, 0, false, _amount, _amount, 0, false, 0, block.timestamp);
        rwaReleaseIds.push(_tokenId);
        existingReleases[_tokenId] = true;

        releaseOwnershipStorages[_tokenId] = new GildiManagerOwnershipStorage(_tokenId, _ownershipTrackingTimePeriod);

        emit ReleaseCreated(_tokenId, _amount);
    }

    /// @inheritdoc IGildiManager
    function assignShares(
        uint256 _releaseId,
        UserShare[] calldata _sharesBatch
    ) external override whenLocked(_releaseId) onlyRole(RELEASE_MANAGER_ROLE) {
        if (_sharesBatch.length == 0) {
            revert SharesMustNotBeEmpty();
        }
        if (_sharesBatch.length > 100) {
            revert TooManyShares(100);
        }

        RWARelease storage release = rwaReleases[_releaseId];
        if (release.deleting) {
            revert ReleaseIsDeleting(_releaseId);
        }

        uint256 totalShares = 0;
        for (uint i = 0; i < _sharesBatch.length; i++) {
            totalShares += _sharesBatch[i].shares;

            _creditToken(_releaseId, _sharesBatch[i].user, _sharesBatch[i].shares);

            emit ShareAssigned(_releaseId, _sharesBatch[i].user, _sharesBatch[i].shares);
        }

        if (totalShares > release.unassignedShares) {
            revert InsufficientUnassignedShares(release.unassignedShares, totalShares);
        }

        release.unassignedShares -= totalShares;

        emit SharesAssigned(_releaseId, totalShares);
    }

    /// @inheritdoc IGildiManager
    function startInitialSale(uint256 _releaseId) external override whenLocked(_releaseId) onlyRole(MARKETPLACE_ROLE) {
        RWARelease storage release = rwaReleases[_releaseId];

        if (release.inInitialSale) {
            revert WrongInitialSaleState(!release.inInitialSale, release.inInitialSale);
        }
        if (release.deleting) {
            revert ReleaseIsDeleting(_releaseId);
        }
        if (release.unassignedShares != 0) {
            revert NotFullyAssignedShares();
        }

        release.inInitialSale = true;

        emit InitialSaleStarted(_releaseId);
    }

    /// @inheritdoc IGildiManager
    function endInitialSale(uint256 _releaseId) external override whenLocked(_releaseId) onlyRole(MARKETPLACE_ROLE) {
        RWARelease storage release = rwaReleases[_releaseId];

        if (!release.inInitialSale) {
            revert WrongInitialSaleState(release.inInitialSale, !release.inInitialSale);
        }

        release.inInitialSale = false;
        unlockRelease(_releaseId);

        emit InitialSaleEnded(_releaseId);
    }

    /// @inheritdoc IGildiManager
    function cancelInitialSale(uint256 _releaseId) external override whenLocked(_releaseId) onlyRole(MARKETPLACE_ROLE) {
        RWARelease storage release = rwaReleases[_releaseId];

        if (!release.inInitialSale) {
            revert WrongInitialSaleState(release.inInitialSale, !release.inInitialSale);
        }

        release.inInitialSale = false;

        emit InitialSaleEnded(_releaseId);
    }

    /// @inheritdoc IGildiManager
    function batchDeleteRelease(
        uint256 _releaseId,
        uint256 _batchSizeOwners
    ) external override whenLocked(_releaseId) onlyRole(RELEASE_MANAGER_ROLE) {
        RWARelease storage release = rwaReleases[_releaseId];
        if (_batchSizeOwners == 0 || _batchSizeOwners > 100) {
            revert InvalidBatchSize(1, 100);
        }
        if (release.inInitialSale) {
            revert WrongInitialSaleState(!release.inInitialSale, release.inInitialSale);
        }

        release.deleting = true;
        emit ReleaseMarkedForDeletion(_releaseId);

        // Delete the shares in batches. + Cleanup the ownership mapping.
        for (uint i = 0; i < _batchSizeOwners; i++) {
            if (tokenOwners[_releaseId].length == 0) {
                break;
            }

            address user = tokenOwners[_releaseId][0];
            uint256 amount = userTokenBalance[_releaseId][user].amount;

            // Cleanup the ownership mapping.
            releaseOwnershipStorages[_releaseId].deleteOwnerships(user);
            delete userTokenBalance[_releaseId][user];
            delete isTokenOwner[user][_releaseId];

            // Remove the user from the tokenOwners array.
            tokenOwners[_releaseId][0] = tokenOwners[_releaseId][tokenOwners[_releaseId].length - 1];
            tokenOwners[_releaseId].pop();

            release.deletedShares += amount;
        }

        // If we have deleted all shares, burn the token and delete the release.
        if (tokenOwners[_releaseId].length == 0) {
            gildiToken.burnAllById(_releaseId);
            delete rwaReleases[_releaseId];
            delete existingReleases[_releaseId];
            for (uint i = 0; i < rwaReleaseIds.length; i++) {
                if (rwaReleaseIds[i] == _releaseId) {
                    rwaReleaseIds[i] = rwaReleaseIds[rwaReleaseIds.length - 1];
                    rwaReleaseIds.pop();
                    break;
                }
            }
            delete releaseOwnershipStorages[_releaseId];
            emit ReleaseDeleted(_releaseId);
        }

        emit ReleaseBatchDeleted(_releaseId, release.deletedShares, tokenOwners[_releaseId].length);
    }

    /// @inheritdoc IGildiManager
    function deposit(
        uint256 _tokenId,
        address _account,
        uint256 _amount
    ) external override nonReentrant whenNotLocked(_tokenId) {
        if (!releaseExists(_tokenId)) {
            revert ReleaseDoesNotExist(_tokenId);
        }
        if (gildiToken.balanceOf(_account, _tokenId) < _amount) {
            revert InsufficientAvailableBalance(_tokenId, _account);
        }
        if (_amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (_msgSender() != _account && !hasRole(ADMIN_ROLE, _msgSender())) {
            revert AccessControlUnauthorizedAccount(_msgSender(), ADMIN_ROLE);
        }

        gildiToken.safeTransferFrom(_account, address(this), _tokenId, _amount, '');

        _creditToken(_tokenId, _account, _amount);

        emit TokenDeposited(_tokenId, _account, _amount);
    }

    /// @inheritdoc IGildiManager
    function withdraw(
        uint256 _tokenId,
        address _account,
        uint256 _amount
    ) external override nonReentrant whenNotLocked(_tokenId) {
        if (!releaseExists(_tokenId)) {
            revert ReleaseDoesNotExist(_tokenId);
        }
        if (_msgSender() != _account && !hasRole(ADMIN_ROLE, _msgSender())) {
            revert AccessControlUnauthorizedAccount(_msgSender(), ADMIN_ROLE);
        }
        if (getAvailableBalance(_tokenId, _account) < _amount) {
            revert InsufficientAvailableBalance(_tokenId, _account);
        }
        if (_amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        gildiToken.safeTransferFrom(address(this), _account, _tokenId, _amount, '');

        _debitToken(_tokenId, _account, _amount);

        emit TokenWithdrawn(_tokenId, _account, _amount);
    }

    /// @inheritdoc IGildiManager
    function transferOwnership(
        uint256 _tokenId,
        address _from,
        address _to,
        uint256 _amount
    ) external override nonReentrant whenNotLocked(_tokenId) {
        if (_msgSender() != _from && !hasRole(ADMIN_ROLE, _msgSender()) && !hasRole(MARKETPLACE_ROLE, _msgSender())) {
            bytes32[] memory roles = new bytes32[](2);
            roles[0] = ADMIN_ROLE;
            roles[1] = MARKETPLACE_ROLE;
            revert AccessControlUnauthorizedAccountAny(_msgSender(), roles);
        }

        _transferOwnership(_tokenId, _from, _to, _amount);

        emit TokenTransferred(_tokenId, _from, _to, _amount);
    }

    /// @inheritdoc IGildiManager
    function transferOwnershipInitialSale(
        uint256 _tokenId,
        address _from,
        address _to,
        uint256 _amount
    ) external override nonReentrant onlyRole(MARKETPLACE_ROLE) {
        RWARelease storage release = rwaReleases[_tokenId];
        if (!release.inInitialSale) {
            revert WrongInitialSaleState(release.inInitialSale, !release.inInitialSale);
        }

        _transferOwnership(_tokenId, _from, _to, _amount);

        emit TokenTransferred(_tokenId, _from, _to, _amount);
    }

    /// @inheritdoc IGildiManager
    function unlockTokens(
        address _account,
        uint256 _tokenId,
        uint256 _amountToUnlock
    ) external onlyRole(MARKETPLACE_ROLE) {
        uint256 lockedAmount = userTokenBalance[_tokenId][_account].lockedAmount;
        if (lockedAmount < _amountToUnlock) {
            revert InsufficientAvailableBalance(_tokenId, _account);
        }

        userTokenBalance[_tokenId][_account].lockedAmount -= _amountToUnlock;

        emit TokenUnlocked(_tokenId, _account, _amountToUnlock);
    }

    /// @inheritdoc IGildiManager
    function lockTokens(address _account, uint256 _tokenId, uint256 _amountToLock) external onlyRole(MARKETPLACE_ROLE) {
        uint256 availableBalance = getAvailableBalance(_tokenId, _account);
        if (availableBalance < _amountToLock) {
            revert InsufficientAvailableBalance(_tokenId, _account);
        }

        userTokenBalance[_tokenId][_account].lockedAmount += _amountToLock;

        emit TokenLocked(_tokenId, _account, _amountToLock);
    }

    /// @notice Get the owners of a token.
    /// @return The token owners.
    function ownersOfToken(uint256 _tokenId) public view returns (address[] memory) {
        return tokenOwners[_tokenId];
    }

    /// @inheritdoc IGildiManager
    function getReleaseById(uint256 _releaseId) external view returns (RWARelease memory) {
        return rwaReleases[_releaseId];
    }

    /// @inheritdoc IGildiManager
    function isLocked(uint256 _releaseId) external view returns (bool) {
        return rwaReleases[_releaseId].locked;
    }

    /// @inheritdoc IGildiManager
    function isInInitialSale(uint256 _releaseId) external view returns (bool) {
        return rwaReleases[_releaseId].inInitialSale;
    }

    /// @inheritdoc IGildiManager
    function balanceOf(address _account) external view override returns (TokenBalance[] memory) {
        TokenBalance[] memory balances = new TokenBalance[](rwaReleaseIds.length);

        for (uint i = 0; i < rwaReleaseIds.length; i++) {
            uint256 tokenId = rwaReleaseIds[i];
            TokenBalance memory balance = userTokenBalance[tokenId][_account];
            if (balance.tokenId != tokenId) {
                balances[i] = TokenBalance(tokenId, 0, 0);
            } else {
                balances[i] = balance;
            }
        }

        return balances;
    }

    /// @inheritdoc IGildiManager
    function balanceOf(uint256 _tokenId, address _account) external view override returns (TokenBalance memory) {
        TokenBalance memory balance = userTokenBalance[_tokenId][_account];
        if (balance.tokenId != _tokenId) {
            return TokenBalance(_tokenId, 0, 0);
        }
        return balance;
    }

    /// @inheritdoc IGildiManager
    function isFullyAssigned(uint256 _releaseId) external view override returns (bool) {
        RWARelease storage release = rwaReleases[_releaseId];
        return releaseExists(_releaseId) && release.unassignedShares == 0;
    }

    /// @inheritdoc IGildiManager
    function fetchSharesInPeriod(
        uint256 _tokenId,
        uint256 _start,
        uint256 _end,
        uint256 _cursor,
        uint256 _limit
    ) external view override returns (SharesReport memory) {
        if (!releaseExists(_tokenId)) {
            revert ReleaseDoesNotExist(_tokenId);
        }

        GildiManagerOwnershipStorage gildiOwnershipTracker = releaseOwnershipStorages[_tokenId];
        uint256 TIME_PERIOD = gildiOwnershipTracker.TIME_PERIOD();

        RWARelease storage release = rwaReleases[_tokenId];
        uint256 releaseUnlockedAtNormalized = (release.unlockedAt / TIME_PERIOD) * TIME_PERIOD;

        _start = (_start / TIME_PERIOD) * TIME_PERIOD;
        _end = (_end / TIME_PERIOD) * TIME_PERIOD;

        if (_start < releaseUnlockedAtNormalized) {
            _start = releaseUnlockedAtNormalized;
        }

        if (_end <= _start) {
            _end = _start + TIME_PERIOD; // Fetch at least one period.
        }

        uint256 totalShares = 0;

        // Dynamic array for user shares
        UserShare[] memory tempUserShares = new UserShare[](_limit);
        bool hasMore = false;
        uint256 nextCursor = _cursor;
        uint256 count = 0;

        address[] memory ownersByTokenId = gildiOwnershipTracker.fetchUsers();

        // Iterate through each ownership and calculate the total number of shares.
        for (uint256 i = _cursor; i < ownersByTokenId.length; i++) {
            if (count >= _limit) {
                hasMore = true;
                break;
            }

            address user = ownersByTokenId[i];
            GildiManagerOwnershipStorage.Ownership[] memory ownerships = gildiOwnershipTracker.fetchOwnerships(user);

            // Iterate through each ownership and calculate the total number of shares, fill gaps with the last value.
            uint256 shares = 0;
            uint256 lastShares = ownerships.length > 0 ? ownerships[ownerships.length - 1].amount : 0;
            uint256 lastTimestamp = (_start < releaseUnlockedAtNormalized ? releaseUnlockedAtNormalized : _start) -
                TIME_PERIOD;

            for (uint256 j = 0; j < ownerships.length; j++) {
                GildiManagerOwnershipStorage.Ownership memory ownership = ownerships[j];

                uint256 timestamp = ownership.timestamp;
                if (timestamp == 0 && release.unlockedAt != 0) {
                    timestamp = (release.unlockedAt / TIME_PERIOD) * TIME_PERIOD;
                }
                if (timestamp >= _start && timestamp < _end) {
                    uint256 gapsToFill = ((timestamp - lastTimestamp) / TIME_PERIOD) - 1;
                    if (gapsToFill > 0) {
                        uint256 sharesToAdd = gapsToFill * lastShares;
                        shares += sharesToAdd;
                    }

                    shares += ownership.amount;

                    lastShares = ownership.amount;
                    lastTimestamp = timestamp;
                }
            }

            uint256 gapsToEnd = ((_end - lastTimestamp) / TIME_PERIOD) - 1;
            if (gapsToEnd > 0) {
                uint256 sharesToAdd = gapsToEnd * lastShares;
                shares += sharesToAdd;
            }

            if (shares > 0) {
                tempUserShares[count] = UserShare(user, shares);
                totalShares += shares;
                count++;
            }

            nextCursor++;
        }

        // Resize the array to the actual count
        UserShare[] memory userShares = new UserShare[](count);
        for (uint256 k = 0; k < count; k++) {
            userShares[k] = tempUserShares[k];
        }

        return SharesReport(_tokenId, _start, _end, totalShares, userShares, hasMore, nextCursor);
    }

    function _transferOwnership(uint256 _tokenId, address _from, address _to, uint256 _amount) internal {
        if (!releaseExists(_tokenId)) {
            revert ReleaseDoesNotExist(_tokenId);
        }

        if (_to == address(0)) {
            revert AddressZeroNotAllowed();
        }

        if (_amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        if (_from == _to) {
            return;
        }

        if (getAvailableBalance(_tokenId, _from) < _amount) {
            revert InsufficientAvailableBalance(_tokenId, _from);
        }

        _debitToken(_tokenId, _from, _amount);
        _creditToken(_tokenId, _to, _amount);
    }

    function _creditToken(uint256 _tokenId, address _account, uint256 _amount) private {
        GildiManagerOwnershipStorage gildiOwnershipTracker = releaseOwnershipStorages[_tokenId];
        uint256 TIME_PERIOD = gildiOwnershipTracker.TIME_PERIOD();
        GildiManagerOwnershipStorage.Ownership[] memory ownerships = gildiOwnershipTracker.fetchOwnerships(_account);

        RWARelease storage release = rwaReleases[_tokenId];
        uint256 timestamp = !release.locked ? (block.timestamp / TIME_PERIOD) * TIME_PERIOD : 0;

        /// First balance processing, then ownership processing.
        if (!isTokenOwner[_account][_tokenId]) {
            tokenOwners[_tokenId].push(_account);
            isTokenOwner[_account][_tokenId] = true;
            userTokenBalance[_tokenId][_account] = TokenBalance(_tokenId, _amount, 0);
        } else {
            userTokenBalance[_tokenId][_account].amount += _amount;
        }

        // Now we process the ownerships.
        if (ownerships.length == 0) {
            gildiOwnershipTracker.pushOwnership(_account, GildiManagerOwnershipStorage.Ownership(_amount, timestamp));
        } else {
            GildiManagerOwnershipStorage.Ownership memory lastOwnership = ownerships[ownerships.length - 1];
            bool lastOwnershipChanged = false;
            if (lastOwnership.timestamp == 0 && !release.locked) {
                lastOwnership.timestamp = (release.unlockedAt / TIME_PERIOD) * TIME_PERIOD;
                lastOwnershipChanged = true;
            }

            uint256 newAmount = lastOwnership.amount + _amount;
            if (lastOwnership.timestamp == timestamp) {
                lastOwnership.amount = newAmount;
                lastOwnershipChanged = true;
            } else {
                gildiOwnershipTracker.pushOwnership(
                    _account,
                    GildiManagerOwnershipStorage.Ownership(newAmount, timestamp)
                );
            }

            if (lastOwnershipChanged) {
                gildiOwnershipTracker.updateOwnershipEntry(_account, ownerships.length - 1, lastOwnership);
            }
        }
    }

    function _debitToken(uint256 _tokenId, address _account, uint256 _amount) private {
        GildiManagerOwnershipStorage ownershipTracker = releaseOwnershipStorages[_tokenId];
        uint256 TIME_PERIOD = ownershipTracker.TIME_PERIOD();
        GildiManagerOwnershipStorage.Ownership[] memory ownerships = ownershipTracker.fetchOwnerships(_account);

        RWARelease storage release = rwaReleases[_tokenId];
        uint256 newAmount = userTokenBalance[_tokenId][_account].amount - _amount;
        uint256 timestamp = !release.locked ? (block.timestamp / TIME_PERIOD) * TIME_PERIOD : 0;

        // First balance processing
        if (newAmount != 0) {
            userTokenBalance[_tokenId][_account].amount = newAmount;
        } else {
            delete userTokenBalance[_tokenId][_account];
            delete isTokenOwner[_account][_tokenId];
            for (uint i = 0; i < tokenOwners[_tokenId].length; i++) {
                if (tokenOwners[_tokenId][i] == _account) {
                    tokenOwners[_tokenId][i] = tokenOwners[_tokenId][tokenOwners[_tokenId].length - 1];
                    tokenOwners[_tokenId].pop();
                    break;
                }
            }
        }

        // Now ownership processing
        bool lastOwnershipChanged = false;
        GildiManagerOwnershipStorage.Ownership memory lastOwnership = ownerships[ownerships.length - 1];

        if (lastOwnership.timestamp == 0 && !release.locked) {
            lastOwnership.timestamp = (release.unlockedAt / TIME_PERIOD) * TIME_PERIOD;
            lastOwnershipChanged = true;
        }

        if (lastOwnership.timestamp == timestamp) {
            lastOwnership.amount -= _amount;
            lastOwnershipChanged = true;
        } else {
            ownershipTracker.pushOwnership(_account, GildiManagerOwnershipStorage.Ownership(newAmount, timestamp));
        }

        if (lastOwnershipChanged) {
            ownershipTracker.updateOwnershipEntry(_account, ownerships.length - 1, lastOwnership);
        }
    }

    function _releaseIsDeleting(uint256 _tokenId) private view returns (bool) {
        return rwaReleases[_tokenId].deleting;
    }

    function _rolesReleaseManagerMarketplace() internal pure returns (bytes32[] memory) {
        bytes32[] memory roles = new bytes32[](2);
        roles[0] = RELEASE_MANAGER_ROLE;
        roles[1] = MARKETPLACE_ROLE;
        return roles;
    }

    modifier whenNotLocked(uint256 _tokenId) {
        if (rwaReleases[_tokenId].locked) {
            revert InvalidLockState(false, true);
        }
        _;
    }

    modifier whenLocked(uint256 _tokenId) {
        if (!rwaReleases[_tokenId].locked) {
            revert InvalidLockState(true, false);
        }
        _;
    }

    modifier onlyRoles(bytes32[] memory _roles) {
        for (uint i = 0; i < _roles.length; i++) {
            if (!hasRole(_roles[i], _msgSender())) {
                revert AccessControlUnauthorizedAccount(_msgSender(), _roles[i]);
            }
        }
        _;
    }

    modifier onlyRoleAny(bytes32[] memory _roles) {
        bool anyRole = false;
        for (uint i = 0; i < _roles.length; i++) {
            if (hasRole(_roles[i], _msgSender())) {
                anyRole = true;
                break;
            }
        }
        if (!anyRole) {
            revert AccessControlUnauthorizedAccountAny(_msgSender(), _roles);
        }
        _;
    }
}
