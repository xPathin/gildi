// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.

pragma solidity 0.8.24;

import '../interfaces/manager/IGildiManager.sol';
import './RoyaltyDistributionSharedStructs.sol';
import './RoyaltyClaimStorage.sol';

import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/// @title RoyaltyDistributor
/// @notice A contract to distribute royalties in different currencies to users.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
contract RoyaltyDistributor is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ROYALTY_MANAGER_ROLE = keccak256('ROYALTY_MANAGER_ROLE');
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @notice The Gildi Manager.
    IGildiManager private gildiManager;
    /// @notice The current distribution ID.
    uint256 private currentDistributionId;

    // All distributions and distributions to release mappings.
    mapping(uint256 => Distribution) private distributions;
    mapping(uint256 => uint256[]) private distributionsByReleaseId;
    uint256[] private distributionIds;
    uint256[] private releaseIds;

    // Allowed assets we can generate distributions for.
    mapping(address => bool) private allowedAssets;
    address[] private allowedAssetsArray;

    /// Storage where the claims are stored on a release ID basis, deployed for each distribution by the Royal Distributor smart contract.
    mapping(uint256 => RoyaltyClaimStorage) public royaltyClaimStorages;

    // Tracking of distribution claims.
    mapping(address => uint256[]) private userClaimDistributionIds;
    mapping(uint256 => address[]) private distributionClaimUsers;

    // Tracking of distribution shares. Only used temporarily for the calculation of the claims.
    mapping(uint256 => DistributionShares) private distributionShares;

    struct Distribution {
        /// @notice An internal ID for the distribution.
        uint256 distributionId;
        /// @notice The ID of the release.
        uint256 rwaReleaseId;
        /// @notice The start of the time period for the distribution.
        uint256 start;
        /// @notice The end of the time period for the distribution.
        uint256 end;
        /// @notice The date and time until the distribution must be claimed. = 0 forever
        uint256 claimableUntil;
        /// @notice The royalty amounts.
        RoyaltyDistributionSharedStructs.AssetValue[] royaltiesToPayout;
        /// @notice From ownership mapping calculated amounts.
        RoyaltyDistributionSharedStructs.AssetValue[] calculatedRoyaltiesToPayout;
        /// @notice The amounts distributed.
        RoyaltyDistributionSharedStructs.AssetValue[] amountsDistributed;
        /// @notice The total number of shares.
        uint256 totalShares;
        /// @notice Whether or not all shares are assigned. (needs to be true to init claims)
        bool allSharesAssigned;
        /// @notice Whether or not all claims are assigned. (needs to be true to prime the distribution)
        bool allClaimsAssigned;
        /// @notice Whether or not the distribution is primed. (needs to be true to activate the distribution)
        bool primed;
        /// @notice Whether or not the distribution is active.
        bool active;
        /// @notice Whether or not the distribution is cancelled.
        bool cancelled;
        /// @notice The date and time when the distribution was created.
        uint256 createdAt;
    }

    event DistributionCreated(
        uint256 indexed distributionId,
        uint256 indexed rwaReleaseId,
        uint256 start,
        uint256 end,
        uint256 claimUntil,
        uint256 createdAt
    );

    struct DistributionShares {
        uint256 totalNumberOfShares;
        IGildiManager.UserShare[] userShares;
        uint256 sharesReportNextCursor;
        uint256 userSharesNextIndex;
    }

    event AssetAllowed(address indexed assetAddress, bool allowed);
    event AssetTopUp(address indexed assetAddress, uint256 amount);
    event AssetEmergencyWithdraw(address indexed assetAddress, address indexed to, uint256 amount);
    event ClaimPeriodSet(uint256 indexed distributionId, uint256 claimUntil);
    event DistributionSharesInitialised(uint256 indexed distributionId, uint256 batchSize, bool hasMore);
    event ClaimAssigned(uint256 indexed distributionId, address indexed user, address[] tokens, uint256[] amounts);
    event DistributionClaimsInitialised(uint256 indexed distributionId, uint256 batchSize, bool allClaimsAssigned);
    event DistributionPrimed(uint256 indexed distributionId);
    event DistributionActivated(uint256 indexed distributionId);
    event DistributionClaimed(
        uint256 indexed distributionId,
        address indexed user,
        address[] tokens,
        uint256[] amounts
    );
    event AssetTransfer(address indexed assetAddress, address indexed from, address indexed to, uint256 amount);
    event DistributionCancelled(uint256 indexed distributionId);

    error DistributionDoesNotExist();
    error ReleaseDoesNotExist();
    error ReleaseSharesNotFullyAssigned();
    error ClaimPeriodOver();
    error AssetNotAllowed(address assetAddress);
    error InvalidAssetAmount(address assetAddress);
    error DistributionAssetsNotUnique(address assetAddress);
    error SharesAlreadyAssigned();
    error SharesNotAssigned();
    error DistributionIsCancelled();
    error ClaimsAlreadyAssigned();
    error ClaimsNotAssigned();
    error InsufficientFundsSent();
    error DistributionAlreadyPrimed();
    error InsufficientMessageValue();
    error DistributionNotPrimed();
    error DistributionAlreadyActive();
    error DistributionIsActive();
    error DistributionNotActive();
    error ClaimDoesNotExist();
    error ClaimAlreadyClaimed();
    error DistributionNotClaimable();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @param _defaultAdmin The default admin.
    /// @param _initialAdmin The initial admin.
    /// @param _initialRoyaltyManager The initial royalty manager.
    /// @param _gildiManager The Gildi Manager.
    function initialize(
        address _defaultAdmin,
        address _initialAdmin,
        address _initialRoyaltyManager,
        IGildiManager _gildiManager
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        if (_initialAdmin != address(0)) {
            _grantRole(ADMIN_ROLE, _initialAdmin);
        }
        if (_initialRoyaltyManager != address(0)) {
            _grantRole(ROYALTY_MANAGER_ROLE, _initialRoyaltyManager);
        }

        gildiManager = _gildiManager;
        currentDistributionId = 1;
    }

    function isUserClaimable(uint256 _distributionId, address _user) public view returns (bool) {
        if (!distributionExists(_distributionId)) {
            return false;
        }
        Distribution storage distribution = distributions[_distributionId];

        if (!distribution.active) {
            return false;
        }

        if (distribution.cancelled) {
            return false;
        }

        if (distribution.claimableUntil != 0 && block.timestamp > distribution.claimableUntil) {
            return false;
        }

        RoyaltyClaimStorage royaltyClaimStorage = royaltyClaimStorages[_distributionId];
        RoyaltyDistributionSharedStructs.Claim memory userClaim;
        if (royaltyClaimStorage.hasClaim(_user)) {
            userClaim = royaltyClaimStorage.fetchClaim(_user);
        }

        if (userClaim.createdAt == 0) {
            return false;
        }

        if (userClaim.claimed) {
            return false;
        }

        return true;
    }

    function distributionExists(uint256 _distributionId) public view returns (bool) {
        return distributions[_distributionId].createdAt > 0;
    }

    function isAllowedAsset(address _assetAddress) public view returns (bool) {
        return allowedAssets[_assetAddress];
    }

    /// @notice Creates a new distribution.
    /// @param _rwaReleaseId The ID of the RWA release.
    /// @param _start The start of the time period.
    /// @param _end The end of the time period.
    /// @param _claimableUntil The date and time until the distribution must be claimed.
    /// @param _distributionAmounts The distribution amounts.
    function createDistribution(
        uint256 _rwaReleaseId,
        uint256 _start,
        uint256 _end,
        uint256 _claimableUntil,
        RoyaltyDistributionSharedStructs.AssetValue[] calldata _distributionAmounts
    ) external onlyRole(ROYALTY_MANAGER_ROLE) {
        if (!gildiManager.releaseExists(_rwaReleaseId)) {
            revert ReleaseDoesNotExist();
        }
        if (_claimableUntil != 0 && _claimableUntil < block.timestamp) {
            revert ClaimPeriodOver();
        }
        for (uint256 i = 0; i < _distributionAmounts.length; i++) {
            if (!isAllowedAsset(_distributionAmounts[i].assetAddress)) {
                revert AssetNotAllowed(_distributionAmounts[i].assetAddress);
            }

            if (_distributionAmounts[i].amount == 0) {
                revert InvalidAssetAmount(_distributionAmounts[i].assetAddress);
            }
        }

        for (uint256 i = 0; i < _distributionAmounts.length; i++) {
            for (uint256 j = i + 1; j < _distributionAmounts.length; j++) {
                if (_distributionAmounts[i].assetAddress == _distributionAmounts[j].assetAddress) {
                    revert DistributionAssetsNotUnique(_distributionAmounts[i].assetAddress);
                }
            }
        }

        Distribution storage newDistribution = distributions[currentDistributionId];
        newDistribution.distributionId = currentDistributionId++;
        newDistribution.rwaReleaseId = _rwaReleaseId;
        newDistribution.start = _start;
        newDistribution.end = _end;
        newDistribution.claimableUntil = _claimableUntil;
        newDistribution.royaltiesToPayout = _distributionAmounts;
        newDistribution.createdAt = block.timestamp;
        newDistribution.calculatedRoyaltiesToPayout = new RoyaltyDistributionSharedStructs.AssetValue[](
            _distributionAmounts.length
        );
        newDistribution.amountsDistributed = new RoyaltyDistributionSharedStructs.AssetValue[](
            _distributionAmounts.length
        );

        for (uint256 i = 0; i < _distributionAmounts.length; i++) {
            newDistribution.calculatedRoyaltiesToPayout[i] = RoyaltyDistributionSharedStructs.AssetValue(
                _distributionAmounts[i].assetAddress,
                0
            );
            newDistribution.amountsDistributed[i] = RoyaltyDistributionSharedStructs.AssetValue(
                _distributionAmounts[i].assetAddress,
                0
            );
        }

        royaltyClaimStorages[newDistribution.distributionId] = new RoyaltyClaimStorage(newDistribution.distributionId);

        if (distributionsByReleaseId[_rwaReleaseId].length == 0) {
            releaseIds.push(_rwaReleaseId);
        }
        distributionsByReleaseId[_rwaReleaseId].push(newDistribution.distributionId);
        distributionIds.push(newDistribution.distributionId);

        emit DistributionCreated(
            newDistribution.distributionId,
            newDistribution.rwaReleaseId,
            newDistribution.start,
            newDistribution.end,
            newDistribution.claimableUntil,
            newDistribution.createdAt
        );
    }

    /// @notice Gets the shares report batched and assigns the total number of shares to the distribution struct. Also assigns the user shares to a temporary storage.
    /// @param distributionId The distribution ID.
    /// @param batchSize The batch size.
    function initDistributionSharesBatched(
        uint256 distributionId,
        uint256 batchSize
    ) external onlyRole(ROYALTY_MANAGER_ROLE) {
        if (!distributionExists(distributionId)) {
            revert DistributionDoesNotExist();
        }
        Distribution storage distribution = distributions[distributionId];

        if (!gildiManager.isFullyAssigned(distribution.rwaReleaseId)) {
            revert ReleaseSharesNotFullyAssigned();
        }

        if (distribution.cancelled) {
            revert DistributionIsCancelled();
        }

        if (distribution.allSharesAssigned) {
            revert SharesAlreadyAssigned();
        }

        DistributionShares storage distributionSharesTracking = distributionShares[distributionId];

        IGildiManager.SharesReport memory sharesReport = gildiManager.fetchSharesInPeriod(
            distribution.rwaReleaseId,
            distribution.start,
            distribution.end,
            distributionSharesTracking.sharesReportNextCursor,
            batchSize
        );

        distributionSharesTracking.sharesReportNextCursor = sharesReport.nextCursor;
        for (uint256 i = 0; i < sharesReport.userShares.length; i++) {
            distributionSharesTracking.userShares.push(sharesReport.userShares[i]);
        }

        if (!sharesReport.hasMore) {
            distribution.allSharesAssigned = true;
        }
        distributionSharesTracking.totalNumberOfShares += sharesReport.totalNumberOfShares;

        emit DistributionSharesInitialised(distributionId, batchSize, sharesReport.hasMore);
    }

    /// @notice Calculates the claims and value needed for the distribution batched.
    /// @param distributionId The distribution ID.
    /// @param batchSize The batch size.
    function initClaimsBatched(uint256 distributionId, uint256 batchSize) external onlyRole(ROYALTY_MANAGER_ROLE) {
        if (!distributionExists(distributionId)) {}
        Distribution storage distribution = distributions[distributionId];

        if (distribution.cancelled) {
            revert DistributionIsCancelled();
        }

        if (!distribution.allSharesAssigned) {
            revert SharesNotAssigned();
        }

        if (distribution.allClaimsAssigned) {
            revert ClaimsAlreadyAssigned();
        }

        DistributionShares storage distributionSharesTracking = distributionShares[distributionId];
        RoyaltyClaimStorage royaltyClaimStorage = royaltyClaimStorages[distributionId];

        uint256 count = 0;
        for (
            uint256 i = distributionSharesTracking.userSharesNextIndex;
            i < distributionSharesTracking.userShares.length;
            i++
        ) {
            if (count >= batchSize) {
                break;
            }

            // Calculate the claims.
            IGildiManager.UserShare memory userShare = distributionSharesTracking.userShares[i];
            address user = userShare.user;
            uint256 shareAmount = userShare.shares;

            RoyaltyDistributionSharedStructs.Claim memory userClaim = RoyaltyDistributionSharedStructs.Claim(
                distributionId,
                user,
                new RoyaltyDistributionSharedStructs.AssetValue[](distribution.royaltiesToPayout.length),
                shareAmount,
                block.timestamp,
                false
            );

            address[] memory tokens = new address[](distribution.royaltiesToPayout.length);
            uint256[] memory amounts = new uint256[](distribution.royaltiesToPayout.length);

            for (uint256 j = 0; j < distribution.royaltiesToPayout.length; j++) {
                uint256 amount = (distribution.royaltiesToPayout[j].amount * shareAmount) /
                    distributionSharesTracking.totalNumberOfShares;
                userClaim.assetValues[j] = RoyaltyDistributionSharedStructs.AssetValue(
                    distribution.royaltiesToPayout[j].assetAddress,
                    amount
                );

                distribution.calculatedRoyaltiesToPayout[j].amount += amount;

                tokens[j] = distribution.royaltiesToPayout[j].assetAddress;
                amounts[j] = amount;
            }

            royaltyClaimStorage.setClaim(user, userClaim);
            userClaimDistributionIds[user].push(distributionId);
            distributionClaimUsers[distributionId].push(user);

            count++;
            distributionSharesTracking.userSharesNextIndex++;

            emit ClaimAssigned(distributionId, user, tokens, amounts);
        }

        if (distributionSharesTracking.userSharesNextIndex >= distributionSharesTracking.userShares.length) {
            distribution.allClaimsAssigned = true;
            distribution.totalShares = distributionSharesTracking.totalNumberOfShares;
            delete distributionShares[distributionId];
        }

        emit DistributionClaimsInitialised(distributionId, batchSize, distribution.allClaimsAssigned);
    }

    function primeDistribution(uint256 _distributionId, address _fundsSource) external onlyRole(ROYALTY_MANAGER_ROLE) {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }

        if (_fundsSource == address(0)) {
            _fundsSource = _msgSender();
        }

        Distribution storage distribution = distributions[_distributionId];

        if (distribution.cancelled) {
            revert DistributionIsCancelled();
        }

        if (!distribution.allClaimsAssigned) {
            revert ClaimsNotAssigned();
        }

        if (distribution.primed) {
            revert DistributionAlreadyPrimed();
        }

        // transfer funds to the contract
        for (uint256 i = 0; i < distribution.calculatedRoyaltiesToPayout.length; i++) {
            RoyaltyDistributionSharedStructs.AssetValue memory totalAmount = distribution.calculatedRoyaltiesToPayout[
                i
            ];

            _transferAsset(totalAmount.assetAddress, _fundsSource, address(this), totalAmount.amount);
        }

        distribution.primed = true;
        emit DistributionPrimed(_distributionId);
    }

    function activateDistribution(uint256 _distributionId) external onlyRole(ROYALTY_MANAGER_ROLE) {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }
        Distribution storage distribution = distributions[_distributionId];

        if (distribution.cancelled) {
            revert DistributionIsCancelled();
        }

        if (!distribution.primed) {
            revert DistributionNotPrimed();
        }

        if (distribution.active) {
            revert DistributionAlreadyActive();
        }

        distribution.active = true;

        emit DistributionActivated(_distributionId);
    }

    function cancelDistribution(
        uint256 _distributionId,
        address _unclaimedAmountReceiver
    ) external onlyRole(ADMIN_ROLE) {
        if (_unclaimedAmountReceiver == address(0)) {
            _unclaimedAmountReceiver = _msgSender();
        }
        _cancelAndWithdrawDistribution(_distributionId, _unclaimedAmountReceiver);
    }

    function claim(uint256 _distributionId) external nonReentrant {
        if (!isUserClaimable(_distributionId, _msgSender())) {
            revert DistributionNotClaimable();
        }

        _claimDistribution(_msgSender(), _distributionId);
    }

    function claimAllByReleaseId(uint256 _rwaReleaseId) external nonReentrant {
        for (uint256 i = 0; i < distributionsByReleaseId[_rwaReleaseId].length; i++) {
            uint256 distributionId = distributionsByReleaseId[_rwaReleaseId][i];
            if (isUserClaimable(distributionId, _msgSender())) {
                _claimDistribution(_msgSender(), distributionId);
            }
        }
    }

    function claimAll() external nonReentrant {
        for (uint256 i = 0; i < userClaimDistributionIds[_msgSender()].length; i++) {
            uint256 distributionId = userClaimDistributionIds[_msgSender()][i];
            if (isUserClaimable(distributionId, _msgSender())) {
                _claimDistribution(_msgSender(), distributionId);
            }
        }
    }

    function withdrawAsset(address _assetAddress, address _to, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        _transferAsset(_assetAddress, address(this), _to, _amount);

        emit AssetEmergencyWithdraw(_assetAddress, _to, _amount);
    }

    function topUpAsset(address _assetAddress, uint256 _amount) external payable onlyRole(ADMIN_ROLE) {
        _transferAsset(_assetAddress, _msgSender(), address(this), _amount);

        emit AssetTopUp(_assetAddress, _amount);
    }

    function fetchDistributionById(uint256 _distributionId) external view returns (Distribution memory) {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }
        return distributions[_distributionId];
    }

    function fetchDistributionClaims(
        uint256 _distributionId
    ) external view returns (RoyaltyDistributionSharedStructs.Claim[] memory) {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }
        return royaltyClaimStorages[_distributionId].fetchAllClaims();
    }

    function fetchUserClaimsByReleaseId(
        uint256 _rwaReleaseId,
        address _userId
    ) external view returns (RoyaltyDistributionSharedStructs.Claim[] memory) {
        RoyaltyDistributionSharedStructs.Claim[] memory tempClaims = new RoyaltyDistributionSharedStructs.Claim[](
            distributionsByReleaseId[_rwaReleaseId].length
        );
        uint256 count = 0;
        for (uint256 i = 0; i < distributionsByReleaseId[_rwaReleaseId].length; i++) {
            uint256 distributionId = distributionsByReleaseId[_rwaReleaseId][i];
            RoyaltyClaimStorage royaltyClaimStorage = royaltyClaimStorages[distributionId];

            RoyaltyDistributionSharedStructs.Claim memory userClaim;
            if (royaltyClaimStorage.hasClaim(_userId)) {
                userClaim = royaltyClaimStorage.fetchClaim(_userId);
            }
            if (userClaim.createdAt > 0) {
                tempClaims[count++] = userClaim;
            }
        }

        RoyaltyDistributionSharedStructs.Claim[] memory res = new RoyaltyDistributionSharedStructs.Claim[](count);
        for (uint256 i = 0; i < count; i++) {
            res[i] = tempClaims[i];
        }

        return res;
    }

    function fetchDistributionsByReleaseId(uint256 _rwaReleaseId) external view returns (Distribution[] memory) {
        Distribution[] memory res = new Distribution[](distributionsByReleaseId[_rwaReleaseId].length);
        for (uint256 i = 0; i < distributionsByReleaseId[_rwaReleaseId].length; i++) {
            res[i] = distributions[distributionsByReleaseId[_rwaReleaseId][i]];
        }
        return res;
    }

    function fetchReleaseIdByDistributionId(uint256 _distributionId) external view returns (uint256) {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }
        return distributions[_distributionId].rwaReleaseId;
    }

    function fetchAllowedAssets() external view returns (address[] memory) {
        return allowedAssetsArray;
    }

    function setAssetAllowed(address _assetAddress, bool _allowed) external onlyRole(ADMIN_ROLE) {
        if (_assetAddress == address(0)) {
            revert AssetNotAllowed(_assetAddress);
        }

        allowedAssets[_assetAddress] = _allowed;
        if (_allowed) {
            allowedAssetsArray.push(_assetAddress);
        } else {
            for (uint256 i = 0; i < allowedAssetsArray.length; i++) {
                if (allowedAssetsArray[i] == _assetAddress) {
                    allowedAssetsArray[i] = allowedAssetsArray[allowedAssetsArray.length - 1];
                    allowedAssetsArray.pop();
                    break;
                }
            }
        }

        emit AssetAllowed(_assetAddress, _allowed);
    }

    function _cancelAndWithdrawAllDistributionsOfRelease(
        uint256 _rwaReleaseId,
        address _unclaimedAmountReceiver
    ) private {
        uint256[] memory distributionIdsCopy = distributionsByReleaseId[_rwaReleaseId];
        for (uint256 i = 0; i < distributionIdsCopy.length; i++) {
            _cancelAndWithdrawDistribution(distributionIdsCopy[i], _unclaimedAmountReceiver);
        }
    }

    function _cancelAndWithdrawDistribution(uint256 _distributionId, address _unclaimedAmountReceiver) private {
        if (!distributionExists(_distributionId)) {
            revert DistributionDoesNotExist();
        }
        Distribution storage distribution = distributions[_distributionId];

        if (distribution.active && block.timestamp < distribution.end) {
            revert DistributionIsActive();
        }

        if (distribution.cancelled) {
            revert DistributionIsCancelled();
        }

        distribution.active = false;
        distribution.cancelled = true;

        if (distribution.primed) {
            for (uint256 i = 0; i < distribution.calculatedRoyaltiesToPayout.length; i++) {
                address assetAddress = distribution.calculatedRoyaltiesToPayout[i].assetAddress;
                uint256 unclaimedAmount = distribution.calculatedRoyaltiesToPayout[i].amount -
                    distribution.amountsDistributed[i].amount;

                _transferAsset(assetAddress, address(this), _unclaimedAmountReceiver, unclaimedAmount);
            }
        }

        delete distributionShares[_distributionId];

        for (uint256 i = 0; i < distributionClaimUsers[_distributionId].length; i++) {
            address user = distributionClaimUsers[_distributionId][i];
            for (uint256 j = 0; j < userClaimDistributionIds[user].length; j++) {
                if (userClaimDistributionIds[user][j] == _distributionId) {
                    userClaimDistributionIds[user][j] = userClaimDistributionIds[user][
                        userClaimDistributionIds[user].length - 1
                    ];
                    userClaimDistributionIds[user].pop();
                    break;
                }
            }
        }

        delete distributionClaimUsers[_distributionId];

        emit DistributionCancelled(_distributionId);
    }

    function _transferAsset(address _assetAddress, address _from, address _to, uint256 _amount) private {
        if (_amount == 0) {
            return;
        }

        IERC20 asset = IERC20(_assetAddress);
        if (_from == address(this)) {
            asset.safeTransfer(_to, _amount);
        } else {
            asset.safeTransferFrom(_from, _to, _amount);
        }

        emit AssetTransfer(_assetAddress, _from, _to, _amount);
    }

    function _claimDistribution(address _user, uint256 _distributionId) private {
        if (!isUserClaimable(_distributionId, _user)) {
            return;
        }

        RoyaltyClaimStorage royaltyClaimStorage = royaltyClaimStorages[_distributionId];
        RoyaltyDistributionSharedStructs.Claim memory userClaim = royaltyClaimStorage.fetchClaim(_user);

        Distribution storage distribution = distributions[_distributionId];

        address[] memory assetAddresses = new address[](userClaim.assetValues.length);
        uint256[] memory amounts = new uint256[](userClaim.assetValues.length);
        for (uint256 i = 0; i < userClaim.assetValues.length; i++) {
            RoyaltyDistributionSharedStructs.AssetValue memory assetValue = userClaim.assetValues[i];
            if (assetValue.amount > 0) {
                _transferAsset(assetValue.assetAddress, address(this), _user, assetValue.amount);
            }

            distribution.amountsDistributed[i].amount += assetValue.amount;

            assetAddresses[i] = assetValue.assetAddress;
            amounts[i] = assetValue.amount;
        }

        userClaim.claimed = true;
        royaltyClaimStorage.setClaim(_user, userClaim);

        emit DistributionClaimed(_distributionId, _user, assetAddresses, amounts);
    }
}
