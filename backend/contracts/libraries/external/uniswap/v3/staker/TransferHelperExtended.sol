// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '../periphery/TransferHelper.sol';

library TransferHelperExtended {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(_isContract(token), 'TransferHelperExtended::safeTransferFrom: call to non-contract');
        TransferHelper.safeTransferFrom(token, from, to, value);
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(address token, address to, uint256 value) internal {
        require(_isContract(token), 'TransferHelperExtended::safeTransfer: call to non-contract');
        TransferHelper.safeTransfer(token, to, value);
    }

    /// @notice Unsafe way of checking if a contract exists, but okay for our use case
    /// @param addr The address to check
    /// @return Whether the address is a contract
    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }
}
