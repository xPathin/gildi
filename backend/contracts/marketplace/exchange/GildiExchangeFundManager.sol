// SPDX-License-Identifier: UNLICENSED
// Created for Soonami Venturethon prototype only.
// No redistribution, modification, or commercial use without prior written consent.
// Copyright (c) 2025 Patrick Fischer. All rights reserved.
pragma solidity 0.8.24;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {
    IGildiExchange,
    IGildiExchangePaymentAggregator
} from '../../interfaces/marketplace/exchange/IGildiExchange.sol';
import {IGildiExchangeFundManager} from '../../interfaces/marketplace/exchange/IGildiExchangeFundManager.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {SharedErrors} from '../../libraries/marketplace/exchange/SharedErrors.sol';

/// @title Gildi Exchange Fund Manager
/// @notice Manages fund functionality for the Gildi Exchange marketplace.
/// @custom:security-contact security@gildi.io
/// @author Gildi Company
contract GildiExchangeFundManager is Initializable, ReentrancyGuardUpgradeable, IGildiExchangeFundManager {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    // ========== Events ==========
    /// @notice Emitted when a user claims funds
    /// @param releaseId The ID of the release
    /// @param fundParticipant The fund participant (seller or fee participant) claiming funds
    /// @param amount The amount claimed
    /// @param currency The currency of the fund
    event FundClaimed(uint256 indexed releaseId, address indexed fundParticipant, uint256 amount, address currency);

    /// @notice Emitted when an fund is cancelled and funds are returned
    /// @param releaseId The ID of the release
    /// @param fundParticipant The fund participant (seller or fee participant)
    /// @param returnedTo The address that received the returned funds
    /// @param amount The amount returned
    /// @param currency The currency of the fund
    event FundCancelled(
        uint256 indexed releaseId,
        address indexed fundParticipant,
        address indexed returnedTo,
        uint256 amount,
        address currency
    );

    /// @notice Emitted when an fund is added
    /// @param releaseId The ID of the release
    /// @param fundParticipant The fund participant (seller or fee participant)
    /// @param amount The amount added
    /// @param amountCurrency The currency of the fund amount
    /// @param payoutCurrency The currency to payout in
    event FundAdded(
        uint256 indexed releaseId,
        address indexed fundParticipant,
        uint256 amount,
        address amountCurrency,
        address payoutCurrency
    );

    /// @notice Emitted when funds are transferred to a participant
    /// @param releaseId The ID of the release
    /// @param from The contract address (normally this contract)
    /// @param to The fund participant receiving the funds
    /// @param sourceToken The source token used for payment
    /// @param amount The amount of source token
    /// @param payoutToken The token received by the recipient (may differ from sourceToken if swapped)
    /// @param swapAmount The amount received after swap (if performed)
    /// @param swapRequested Whether a token swap was requested
    /// @param swapSuccessful Whether the swap was successful (if requested)
    /// @param slippageBps The slippage tolerance in basis points used for swaps
    event FundTransferred(
        uint256 indexed releaseId,
        address indexed from,
        address indexed to,
        address sourceToken,
        uint256 amount,
        address payoutToken,
        uint256 swapAmount,
        bool swapRequested,
        bool swapSuccessful,
        uint16 slippageBps
    );

    // ========== Errors ==========
    /// @dev Error thrown when an incompatible currency is provided
    error InvalidCurrency();

    /// @dev Error thrown when a fund is not found
    /// @param releaseId The ID of the release
    /// @param participant The address of the fund participant
    error FundNotFound(uint256 releaseId, address participant);

    // ========== Structs ==========
    /// @notice Structure to hold pending fund amounts for a release
    struct PendingFundAmounts {
        /// @dev The ID of the release
        uint256 releaseId;
        /// @dev The list of participants with funds
        address[] participants;
        /// @dev The fund amounts for each participant
        FundAmount[] amounts;
        /// @dev Whether the funds are claimable
        bool claimable;
    }

    // ========== Constants ==========
    /// @notice Default slippage tolerance in basis points (1%)
    uint16 public constant DEFAULT_SLIPPAGE_BPS = 100;

    // ========== Storage Variables ==========

    /// @notice The GildiExchange contract that calls this contract
    IGildiExchange public gildiExchange;

    /// @notice A set of release IDs that have funds
    EnumerableSet.UintSet private releaseIdsWithFunds;

    /// @notice Maps release IDs to the funds for each participant
    /// @dev releaseId => participant => funds[]
    mapping(uint256 => mapping(address => Fund[])) private releaseFundsByParticipant;

    /// @notice Maps release IDs to all fund participants
    /// @dev releaseId => participants[]
    mapping(uint256 => address[]) private releaseFundParticipants;

    /// @notice Maps release IDs to the total fund amount for each participant
    /// @dev releaseId => participant => amount
    mapping(uint256 => mapping(address => FundAmount)) private releaseFundAmountByParticipant;

    /// @notice Ensures that only the GildiExchange contract can call this function
    modifier onlyGildiExchange() {
        if (msg.sender != address(gildiExchange)) {
            revert SharedErrors.InvalidCaller();
        }
        _;
    }

    /// @notice Ensures that only the payment processor can call this function
    modifier onlyPaymentProcessor() {
        IGildiExchange.AppEnvironment memory env = gildiExchange.getAppEnvironment();
        if (msg.sender != address(env.settings.paymentProcessor)) {
            revert SharedErrors.InvalidCaller();
        }
        _;
    }

    modifier onlyClaimer() {
        IGildiExchange.AppEnvironment memory env = gildiExchange.getAppEnvironment();
        bytes32 claimerRole = env.claimerRole;
        if (!gildiExchange.hasRole(claimerRole, msg.sender)) {
            revert SharedErrors.InvalidCaller();
        }
        _;
    }

    // ========== Constructor and Initializer ==========

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _gildiExchange The address of the GildiExchange contract
    function initialize(address _gildiExchange) external initializer {
        __ReentrancyGuard_init();

        gildiExchange = IGildiExchange(_gildiExchange);
    }

    // ========== External View Functions ==========

    /// @notice Gets all fund participants for a release
    /// @param _releaseId The ID of the release
    /// @return An array of participant addresses
    function getReleaseFundParticipants(uint256 _releaseId) external view returns (address[] memory) {
        return releaseFundParticipants[_releaseId];
    }

    /// @notice Gets the total fund amount for a participant of a release
    /// @param _releaseId The ID of the release
    /// @param _participant The address of the fund participant
    /// @return The fund amount details
    function getReleaseFundAmount(uint256 _releaseId, address _participant) external view returns (FundAmount memory) {
        return releaseFundAmountByParticipant[_releaseId][_participant];
    }

    /// @notice Retrieves funds for a participant of a release
    /// @param _releaseId The ID of the release
    /// @param _participant The address of the fund participant
    /// @param _cursor The starting index for pagination
    /// @param _length The number of funds to retrieve
    /// @return funds An array of funds
    /// @return nextCursor The next cursor for pagination
    function getReleaseFunds(
        uint256 _releaseId,
        address _participant,
        uint256 _cursor,
        uint256 _length
    ) external view returns (Fund[] memory funds, uint256 nextCursor) {
        Fund[] storage participantFunds = releaseFundsByParticipant[_releaseId][_participant];
        if (_cursor >= participantFunds.length) {
            return (new Fund[](0), participantFunds.length);
        }

        // Default length: 100
        if (_length == 0) {
            _length = 100;
        }

        // Return the funds starting from the cursor and limited by length
        uint256 start = _cursor;
        uint256 end = start + _length;
        if (end > participantFunds.length) {
            end = participantFunds.length;
        }

        // Return the funds
        funds = new Fund[](end - start);
        for (uint256 i = start; i < end; i++) {
            funds[i - start] = participantFunds[i];
        }

        nextCursor = end;
    }

    /// @inheritdoc IGildiExchangeFundManager
    function releaseHasFunds(uint256 _releaseId) external view returns (bool) {
        return releaseIdsWithFunds.contains(_releaseId);
    }

    /// @notice Gets all release IDs that have funds
    /// @return An array of release IDs that currently have active funds
    function getReleaseIdsWithFunds() external view returns (uint256[] memory) {
        uint256 length = releaseIdsWithFunds.length();
        uint256[] memory ids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            ids[i] = releaseIdsWithFunds.at(i);
        }

        return ids;
    }

    // ========== External Non-View Functions ==========

    /// @inheritdoc IGildiExchangeFundManager
    function handleAddToFund(
        uint256 _releaseId,
        address _participant,
        address _buyer,
        address _operator,
        bool _isProxyOperation,
        uint256 _amount,
        address _amountCurrency,
        address _payoutCurrency
    ) external onlyPaymentProcessor {
        // Create or add to fund
        if (releaseFundsByParticipant[_releaseId][_participant].length == 0) {
            releaseFundParticipants[_releaseId].push(_participant);
            // Add release to releaseIdsWithFunds if not already added
            if (!releaseIdsWithFunds.contains(_releaseId)) {
                releaseIdsWithFunds.add(_releaseId);
            }
        }

        releaseFundsByParticipant[_releaseId][_participant].push(
            Fund({
                buyer: _buyer,
                operator: _operator,
                fundParticipant: _participant,
                isProxyOperation: _isProxyOperation,
                amount: FundAmount(_amount, _amountCurrency),
                payoutCurrency: _payoutCurrency
            })
        );

        // Update total fund amount
        FundAmount storage fundAmount = releaseFundAmountByParticipant[_releaseId][_participant];
        fundAmount.value += _amount;

        if (fundAmount.currencyAddress == address(0)) {
            fundAmount.currencyAddress = _amountCurrency;
        } else if (fundAmount.currencyAddress != _amountCurrency) {
            revert InvalidCurrency();
        }

        // Emit event for fund added
        emit FundAdded(_releaseId, _participant, _amount, _amountCurrency, _payoutCurrency);
    }

    /// @notice Claims funds for a participant of a release
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Optional slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function claimFunds(uint256 _releaseId, address _fundParticipant, uint16 _slippageBps) external nonReentrant {
        _claimFunds(_releaseId, _fundParticipant, _slippageBps);
    }

    /// @notice Claims funds for a participant of a release with default slippage (5%)
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    function claimFunds(uint256 _releaseId, address _fundParticipant) external nonReentrant {
        _claimFunds(_releaseId, _fundParticipant, DEFAULT_SLIPPAGE_BPS);
    }

    /// @notice Claims all funds for a participant across all releases
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Optional slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function claimAllFunds(address _fundParticipant, uint16 _slippageBps) external nonReentrant {
        _claimAllFunds(_fundParticipant, _slippageBps);
    }

    /// @notice Claims all funds for a participant across all releases with default slippage (5%)
    /// @param _fundParticipant The address of the fund participant
    function claimAllFunds(address _fundParticipant) external nonReentrant {
        _claimAllFunds(_fundParticipant, DEFAULT_SLIPPAGE_BPS);
    }

    /// @notice Claims all funds for all participants of a specific release
    /// @param _releaseId The ID of the release
    function claimAllFundsByReleaseId(uint256 _releaseId) external nonReentrant {
        if (!_isClaimable(_releaseId)) {
            revert SharedErrors.NotAllowed();
        }

        _claimAllFundsByReleaseId(_releaseId);
    }

    /// @notice Claims all funds for all participants across all releases
    function claimAllFunds() external nonReentrant {
        for (uint256 i = releaseIdsWithFunds.length(); i > 0; i--) {
            uint256 releaseId = releaseIdsWithFunds.at(i - 1);

            if (_isClaimable(releaseId)) {
                _claimAllFundsByReleaseId(releaseId);
            }
        }
    }

    /// @inheritdoc IGildiExchangeFundManager
    function handleCancelReleaseFunds(
        uint256 _releaseId,
        uint256 _batchSize
    ) external onlyGildiExchange returns (uint256 processed) {
        uint256 i = 0;

        // Process funds
        while (releaseFundParticipants[_releaseId].length > 0 && i < _batchSize) {
            uint256 length = releaseFundParticipants[_releaseId].length;
            address fundParticipant = releaseFundParticipants[_releaseId][length - 1];
            Fund[] storage funds = releaseFundsByParticipant[_releaseId][fundParticipant];

            while (funds.length > 0 && i < _batchSize) {
                Fund storage fund = funds[funds.length - 1];

                // Determine the correct refund participant based on operation type
                address refundParticipant = fund.isProxyOperation ? fund.buyer : fund.operator;

                try IERC20(fund.amount.currencyAddress).transfer(refundParticipant, fund.amount.value) returns (
                    bool success
                ) {
                    if (!success) continue; // Skip if transfer failed, silently fail, token might be locked
                    emit FundCancelled(
                        _releaseId,
                        fund.fundParticipant,
                        refundParticipant,
                        fund.amount.value,
                        fund.amount.currencyAddress
                    );
                    funds.pop();
                } catch {}
                i++;
            }

            if (funds.length == 0) {
                delete releaseFundsByParticipant[_releaseId][fundParticipant];
                delete releaseFundAmountByParticipant[_releaseId][fundParticipant];
                releaseFundParticipants[_releaseId].pop();

                // Remove release ID from set if no more participants
                if (releaseFundParticipants[_releaseId].length == 0) {
                    releaseIdsWithFunds.remove(_releaseId);
                }
            }
        }

        return i;
    }

    // ========== Public View Functions ==========

    /// @notice Fetches pending fund amounts for a participant and release
    /// @dev if releaseId is 0, fetches for all releases, if participant is 0, fetches for all participants
    /// @param _releaseId The ID of the release
    /// @param _participant The address of the fund participant
    /// @return An array of pending fund amounts with claimable status
    function fetchPendingFundAmounts(
        uint256 _releaseId,
        address _participant
    ) public view returns (PendingFundAmounts[] memory) {
        uint256[] memory releaseIds;

        if (_releaseId != 0) {
            releaseIds = new uint256[](1);
            releaseIds[0] = _releaseId;
        } else {
            uint256 length = releaseIdsWithFunds.length();
            releaseIds = new uint256[](length);

            for (uint256 i = 0; i < length; i++) {
                releaseIds[i] = releaseIdsWithFunds.at(i);
            }
        }

        PendingFundAmounts[] memory tempPendingReleaseAmounts = new PendingFundAmounts[](releaseIds.length);

        uint256 countRelease = 0;
        for (uint256 i = 0; i < releaseIds.length; i++) {
            uint256 releaseId = releaseIds[i];
            address[] storage participants = releaseFundParticipants[releaseId];
            if (participants.length == 0) {
                // Release has no funds
                continue;
            }

            uint256 countParticipants = 0;
            address[] memory tempParticipants = new address[](participants.length);
            FundAmount[] memory tempFundAmounts = new FundAmount[](participants.length);

            for (uint256 j = 0; j < participants.length; j++) {
                address participant = participants[j];
                if (_participant != address(0) && participant != _participant) {
                    continue;
                }

                FundAmount storage fundAmount = releaseFundAmountByParticipant[releaseId][participant];
                if (fundAmount.value == 0) {
                    continue;
                }

                tempParticipants[countParticipants] = participant;
                tempFundAmounts[countParticipants] = fundAmount;
                countParticipants++;
            }

            if (countParticipants == 0) {
                continue;
            }

            // Resize participants and amounts arrays
            address[] memory resizedParticipants = new address[](countParticipants);
            FundAmount[] memory resizedFundAmounts = new FundAmount[](countParticipants);
            for (uint256 k = 0; k < countParticipants; k++) {
                resizedParticipants[k] = tempParticipants[k];
                resizedFundAmounts[k] = tempFundAmounts[k];
            }

            tempPendingReleaseAmounts[countRelease] = PendingFundAmounts({
                releaseId: releaseId,
                participants: resizedParticipants,
                amounts: resizedFundAmounts,
                claimable: _isClaimable(releaseId)
            });
            countRelease++;
        }

        // Resize pending release amounts array
        PendingFundAmounts[] memory pendingReleaseAmounts = new PendingFundAmounts[](countRelease);
        for (uint256 i = 0; i < countRelease; i++) {
            pendingReleaseAmounts[i] = tempPendingReleaseAmounts[i];
        }

        return pendingReleaseAmounts;
    }

    // ========== Internal Functions ==========

    /// @dev Claims funds for a specific participant of a release
    /// @param _releaseId The ID of the release
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function _claimFunds(uint256 _releaseId, address _fundParticipant, uint16 _slippageBps) internal {
        if (_fundParticipant == address(0)) {
            revert SharedErrors.ParamError();
        }

        if (gildiExchange.isInInitialSale(_releaseId)) {
            revert SharedErrors.NotAllowed();
        }

        bytes32 claimerRole = gildiExchange.getAppEnvironment().claimerRole;
        // If the caller does not have CLAIMER_ROLE he is only allowed to claim funds for himself
        if (!gildiExchange.hasRole(claimerRole, msg.sender) && msg.sender != _fundParticipant) {
            revert SharedErrors.NotAllowed();
        }

        // Check if there's an fund to claim
        FundAmount storage fundAmount = releaseFundAmountByParticipant[_releaseId][_fundParticipant];
        if (fundAmount.value == 0) revert FundNotFound(_releaseId, _fundParticipant);

        // Get the fund details to determine the payout currency
        Fund[] storage funds = releaseFundsByParticipant[_releaseId][_fundParticipant];
        if (funds.length == 0) revert FundNotFound(_releaseId, _fundParticipant);

        // Cache these values to reduce stack depth
        uint256 amountValue = fundAmount.value;
        address currencyAddress = fundAmount.currencyAddress;
        address payoutCurrency = funds[0].payoutCurrency;

        // Transfer logic
        _handleFundTransfer(_releaseId, _fundParticipant, amountValue, currencyAddress, payoutCurrency, _slippageBps);

        // Clean up fund data
        delete releaseFundsByParticipant[_releaseId][_fundParticipant];
        delete releaseFundAmountByParticipant[_releaseId][_fundParticipant];

        // Remove fund participant from array using swap-and-pop pattern
        address[] storage fundParticipants = releaseFundParticipants[_releaseId];
        uint256 length = fundParticipants.length;

        for (uint256 i = 0; i < length; i++) {
            if (fundParticipants[i] == _fundParticipant) {
                // Replace with last element and pop
                fundParticipants[i] = fundParticipants[length - 1];
                fundParticipants.pop();
                break;
            }
        }

        // Remove release ID from set if no more participants
        if (fundParticipants.length == 0) {
            releaseIdsWithFunds.remove(_releaseId);
        }

        emit FundClaimed(_releaseId, _fundParticipant, amountValue, currencyAddress);
    }

    /// @dev Claims all funds for a participant across all releases. Iterates backwards
    /// over releases and participants to safely handle state modifications during claims.
    /// @param _fundParticipant The address of the fund participant
    /// @param _slippageBps Slippage tolerance in basis points (100 = 1%, 500 = 5%)
    function _claimAllFunds(address _fundParticipant, uint16 _slippageBps) internal {
        for (uint256 i = releaseIdsWithFunds.length(); i > 0; i--) {
            uint256 releaseId = releaseIdsWithFunds.at(i - 1);

            if (!_isClaimable(releaseId)) {
                continue;
            }

            address[] storage participants = releaseFundParticipants[releaseId];
            // Iterate backwards to avoid skipping elements on mutation
            for (uint256 j = participants.length; j > 0; j--) {
                if (_fundParticipant != address(0) && _fundParticipant == participants[j - 1]) {
                    _claimFunds(releaseId, _fundParticipant, _slippageBps);
                }
            }
        }
    }

    /// @dev Claims all funds for all participants of a specific release
    /// @param _releaseId The ID of the release
    function _claimAllFundsByReleaseId(uint256 _releaseId) internal onlyClaimer {
        address[] storage participants = releaseFundParticipants[_releaseId];
        for (uint256 i = participants.length; i > 0; i--) {
            address fundParticipant = participants[i - 1];
            _claimFunds(_releaseId, fundParticipant, DEFAULT_SLIPPAGE_BPS);
        }
    }

    // ========== Private Functions ==========

    /// @dev Checks if a release is claimable
    /// @param _releaseId The ID of the release
    /// @return True if the release is claimable, false otherwise
    function _isClaimable(uint256 _releaseId) private view returns (bool) {
        if (gildiExchange.isInInitialSale(_releaseId) || !releaseIdsWithFunds.contains(_releaseId)) {
            return false;
        }

        return true;
    }

    /// @dev Handles the transfer logic for a fund claim
    /// @param _fundParticipant The address of the fund participant
    /// @param _amount The amount to transfer
    /// @param _currencyAddress The currency address of the fund
    /// @param _payoutCurrency The preferred payout currency
    /// @param _slippageBps Slippage tolerance in basis points
    function _handleFundTransfer(
        uint256 _releaseId,
        address _fundParticipant,
        uint256 _amount,
        address _currencyAddress,
        address _payoutCurrency,
        uint16 _slippageBps
    ) private {
        uint16 basisPoints = gildiExchange.getAppEnvironment().basisPoints;

        if (_slippageBps > basisPoints) {
            revert SharedErrors.ParamError();
        }

        bool swapRequested = false;
        bool swapSuccessful = false;
        address finalPayoutCurrency = _payoutCurrency;
        uint256 finalAmount = _amount; // Initialize to original amount, will be updated if swap is successful

        // If payout currency is the same as the fund currency or not specified, direct transfer
        if (_payoutCurrency == address(0) || _payoutCurrency == _currencyAddress) {
            IERC20(_currencyAddress).safeTransfer(_fundParticipant, _amount);
            finalPayoutCurrency = _currencyAddress;
        } else {
            swapRequested = true;

            // Get the payment aggregator from the exchange
            IGildiExchangePaymentAggregator paymentAggregator = gildiExchange
                .getAppEnvironment()
                .settings
                .paymentAggregator;

            // If payment aggregator is not set, fallback to direct transfer
            if (address(paymentAggregator) == address(0)) {
                IERC20(_currencyAddress).safeTransfer(_fundParticipant, _amount);
                finalPayoutCurrency = _currencyAddress;
            } else {
                // Approve the payment aggregator to spend the tokens
                IERC20 sourceToken = IERC20(_currencyAddress);
                uint256 allowance = sourceToken.allowance(address(this), address(paymentAggregator));
                if (allowance < _amount) {
                    sourceToken.forceApprove(address(paymentAggregator), type(uint256).max);
                }

                // Preview the swap to get expected amount
                (bool hasValidRoute, uint256 expectedAmount, ) = paymentAggregator.previewSwapOut(
                    _amount,
                    _currencyAddress,
                    _payoutCurrency
                );
                if (hasValidRoute && expectedAmount > 0) {
                    // Calculate minimum amount based on slippage (10000 - slippageBps) / 10000
                    uint256 minAmount = (expectedAmount * (basisPoints - _slippageBps)) / basisPoints;
                    try
                        paymentAggregator.swapOut(
                            _amount,
                            _currencyAddress,
                            _payoutCurrency,
                            minAmount,
                            _fundParticipant
                        )
                    returns (uint256 swapAmount) {
                        // Swap successful
                        swapSuccessful = true;
                        finalPayoutCurrency = _payoutCurrency;
                        finalAmount = swapAmount;
                    } catch {
                        // Swap failed, fallback to direct transfer
                        sourceToken.safeTransfer(_fundParticipant, _amount);
                        finalPayoutCurrency = _currencyAddress;
                    }
                } else {
                    // No valid route, fallback to direct transfer
                    sourceToken.safeTransfer(_fundParticipant, _amount);
                    finalPayoutCurrency = _currencyAddress;
                }
            }
        }

        // Emit fund transferred event
        emit FundTransferred(
            _releaseId,
            address(this),
            _fundParticipant,
            _currencyAddress,
            _amount,
            finalPayoutCurrency,
            finalAmount,
            swapRequested,
            swapSuccessful,
            _slippageBps
        );
    }

    // ---------------------------------------------------------------------------
    // Fallback functions
    // ---------------------------------------------------------------------------

    /// @notice Fallback function to prevent direct Ether transfers
    fallback() external payable {
        revert SharedErrors.NotAllowed();
    }

    /// @notice Fallback function to prevent direct Ether transfers
    receive() external payable {
        revert SharedErrors.NotAllowed();
    }
}
