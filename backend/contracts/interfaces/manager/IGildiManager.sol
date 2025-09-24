// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

/// @title IGildiManager
/// @notice Interface for the Gildi Manager.
/// @custom:security-contact security@gildi.io
/// @author Patrick Fischer (Pathin) > https://pathin.me
interface IGildiManager is IERC165 {
    /// @notice A user share.
    struct UserShare {
        /// @notice The user address.
        address user;
        /// @notice The number shares owned by the user.
        uint256 shares;
    }

    /// @notice A report of the shares owned by a user in a specific time period.
    struct SharesReport {
        /// @notice The token ID.
        uint256 tokenId;
        /// @notice The start timestamp of the report.
        uint256 start;
        /// @notice The end timestamp of the report.
        uint256 end;
        /// @notice The total number of shares owned by all users.
        uint256 totalNumberOfShares;
        /// @notice The shares owned by each user.
        UserShare[] userShares;
        /// @notice Info for Pagination, if there are more results.
        bool hasMore;
        /// @notice Next cursor for Pagination.
        uint256 nextCursor;
    }

    struct TokenBalance {
        uint256 tokenId;
        uint256 amount;
        uint256 lockedAmount;
    }

    /// @notice A GILDI RWA release.
    struct RWARelease {
        /// @notice The token ID of the release (equal to release id).
        uint256 tokenId;
        /// @notice If the release is locked.
        bool locked;
        /// @notice When the release was unlocked.
        uint256 unlockedAt;
        /// @notice If the release is in the initial sale.
        bool inInitialSale;
        /// @notice The total number of shares.
        uint256 totalShares;
        /// @notice The number of unassigned shares.
        uint256 unassignedShares;
        /// @notice The number of burned shares.
        uint256 burnedShares;
        /// @notice The release is deleting.
        bool deleting;
        /// @notice The number of shares deleted.
        uint256 deletedShares;
        /// @notice The timestamp of the creation.
        uint256 createdAt;
    }

    /// @notice Fetches all the release IDs.
    /// @return An array of all the release IDs.
    function getAllReleaseIds() external view returns (uint256[] memory);

    /// @notice Create a new release.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    /// @param _amount The amount of the token.
    /// @param _ownershipTrackingTimePeriod The time period in which we aggregate the shares owned by a user.
    function createNewRelease(uint256 _releaseId, uint256 _amount, uint256 _ownershipTrackingTimePeriod) external;

    /// @notice Assigns the user shares to a royalty rights release in a batch operation.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    /// @param _sharesBatch The shares to assign.
    /// @dev The shares are assigned in a batch to prevent gas limit issues.
    function assignShares(uint256 _releaseId, UserShare[] calldata _sharesBatch) external;

    /// @notice Starts the initial sale of a release.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    function startInitialSale(uint256 _releaseId) external;

    /// @notice Cancels the initial sale of a release.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    function cancelInitialSale(uint256 _releaseId) external;

    /// @notice Ends the initial sale of a release.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    function endInitialSale(uint256 _releaseId) external;

    /// @notice Check if a release exists.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    /// @return True if the release exists, false otherwise.
    function releaseExists(uint256 _releaseId) external view returns (bool);

    /// @notice Deletes a release in batches.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    /// @param _batchSizeOwners The number of owners to delete in a batch.
    /// @dev Batch deletion is used to prevent gas limit issues.
    function batchDeleteRelease(uint256 _releaseId, uint256 _batchSizeOwners) external;

    /// @notice Unlocks a release.
    /// @param _releaseId The ID of the Royalty Rights Token / release.
    function unlockRelease(uint256 _releaseId) external;

    /// @notice Deposits royalty rights tokens into the manager.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _account The account to deposit the tokens to.
    /// @param _amount The amount of tokens to deposit.
    function deposit(uint256 _tokenId, address _account, uint256 _amount) external;

    /// @notice Withdraws royalty rights tokens from the manager.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _account The account to withdraw the tokens from.
    /// @param _amount The amount of tokens to withdraw.
    function withdraw(uint256 _tokenId, address _account, uint256 _amount) external;

    /// @notice Locks tokens for a user.
    /// @param _account The account to lock the tokens for.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _amountToLock The amount of tokens to lock.
    function lockTokens(address _account, uint256 _tokenId, uint256 _amountToLock) external;

    /// @notice Unlocks tokens for a user.
    /// @param _account The account to unlock the tokens for.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _amountToUnlock The amount of tokens to unlock.
    function unlockTokens(address _account, uint256 _tokenId, uint256 _amountToUnlock) external;

    /// @notice Transfers ownership of a release's shares to another user.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _from The address of the current owner.
    /// @param _to The address of the new owner.
    /// @param _amount The amount of shares to transfer.
    function transferOwnership(uint256 _tokenId, address _from, address _to, uint256 _amount) external;

    /// @notice Transfers ownership of a release's shares to another user during the initial sale.
    /// @param _tokenId The ID of the Royalty Rights Token / release.
    /// @param _from The address of the current owner.
    /// @param _to The address of the new owner.
    /// @param _amount The amount of shares to transfer.
    function transferOwnershipInitialSale(uint256 _tokenId, address _from, address _to, uint256 _amount) external;

    /// @notice Gets a release by its ID.
    /// @param _releaseId The release ID.
    /// @return The release.
    function getReleaseById(uint256 _releaseId) external view returns (RWARelease memory);

    /// @notice Checks if the release is locked.
    /// @param _releaseId The release ID.
    /// @return True if the release is locked, false otherwise.
    function isLocked(uint256 _releaseId) external view returns (bool);

    /// @notice Returns if the release is in the initial sale.
    /// @param _releaseId The release ID.
    /// @return True if the release is in the initial sale, false otherwise.
    function isInInitialSale(uint256 _releaseId) external view returns (bool);

    /// @notice Fetches the available balance of a user for a specific token.
    /// @param _tokenId The token ID.
    /// @param _account The account to fetch the balance for.
    /// @return The available balance of the user for the token.
    function getAvailableBalance(uint256 _tokenId, address _account) external view returns (uint256);

    /// @notice Fetch the shares of a release owned by a user in a specific time period paginated.
    /// @param _releaseId The release ID.
    /// @param _start The start timestamp.
    /// @param _end The end timestamp (exclusive).
    /// @param _cursor The cursor for pagination.
    /// @param _limit The limit for pagination.
    function fetchSharesInPeriod(
        uint256 _releaseId,
        uint256 _start,
        uint256 _end,
        uint256 _cursor,
        uint256 _limit
    ) external view returns (SharesReport memory);

    /// @notice Fetches the balance of a user for all tokens.
    /// @param _account The account to fetch the balance for.
    function balanceOf(address _account) external view returns (TokenBalance[] memory);

    /// @notice Fetches the balance of a user for a specific token.
    /// @param _tokenId The token ID.
    /// @param _account The account to fetch the balance for.
    function balanceOf(uint256 _tokenId, address _account) external view returns (TokenBalance memory);

    /// @notice Checks if the release is fully assigned.
    function isFullyAssigned(uint256 _releaseId) external view returns (bool);
}
