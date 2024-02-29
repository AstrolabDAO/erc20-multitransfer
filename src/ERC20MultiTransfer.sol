// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC20 } from "solady/src/tokens/ERC20.sol";

/// @title ERC20MultiTransfer
/// @author AstrolabDAO (https://github.com/AstrolabDAO/erc20-multitransfer/blob/main/src/ERC20MultiTransfer.sol)
/// @author Solady (https://github.com/Vectorized/solady/blob/main/src/tokens/ERC20.sol)
abstract contract ERC20MultiTransfer is ERC20 {

    // redefinition of solady's private constants (should be internal for proper use)
    uint256 private constant _BALANCE_SLOT_SEED = 0x87a211a2;

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 internal constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDON: MULTITRANSFER                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Allows the sender to transfer multiple amounts of tokens to multiple recipients.
     * @param recipients An array of recipient addresses in memory.
     * @param amounts A bytes array in memory where each 64-bit segment represents an amount to be transferred to the corresponding recipient.
     * @param eventful A boolean indicating whether to emit Transfer events for each transfer.
     */
    function _multiSend(address[] memory recipients, bytes memory amounts, bool eventful) internal {

        // Ensure that the amounts array has enough data for all recipients (can be up to 24 bits more depending on padding)
        require(amounts.length > recipients.length * 8);

        uint256 recipientsLength = recipients.length;

        /// @solidity memory-safe-assembly
        assembly {
            let sender := caller()
            // Initialize totalAmount outside the loop
            let totalAmount := 0

            // Loop to calculate total amount to be sent and update recipients' balances
            for { let i := 0 } lt(i, recipientsLength) { i := add(i, 1) } {
                // Directly load the amount from the amounts array in memory
                let amount := mload(add(add(amounts, 32), mul(i, 32))) // Use mul(i, 32) because mload expects byte offsets

                // Accumulate the total amount to be sent
                totalAmount := add(totalAmount, amount)

                // Load the recipient from the recipients array
                let recipient := mload(add(add(recipients, 32), mul(i, 32)))

                // Calculate recipient balance slot
                mstore(0x0c, _BALANCE_SLOT_SEED)
                mstore(0x00, recipient)
                let recipientBalanceSlot := keccak256(0x0c, 0x20)
                let recipientBalance := sload(recipientBalanceSlot)

                // Update recipient's balance
                sstore(recipientBalanceSlot, add(recipientBalance, amount))

                if eventful {
                    mstore(0x20, amount)
                    log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, sender, recipient)
                }
            }

            // Calculate sender balance slot and check balance
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, sender)
            let senderBalanceSlot := keccak256(0x0c, 0x20)
            let senderBalance := sload(senderBalanceSlot)
            if lt(senderBalance, totalAmount) {
                revert(0, 0) // Revert on insufficient balance
            }

            // Update sender's balance
            sstore(senderBalanceSlot, sub(senderBalance, totalAmount))
        }
    }

    /**
     * @dev Executes multiple transfers of tokens to the specified recipients.
     * This function first updates the balances without emitting events, and then emits a Transfer event for each transfer.
     * @param recipients An array of recipient addresses.
     * @param amounts A bytes array where each 64-bit segment represents an amount to be transferred to the corresponding recipient.
     */
    function multiSend(address[] memory recipients, bytes memory amounts) external {
        _multiSend(recipients, amounts, false);
    }

    /**
     * @dev Executes multiple transfers of tokens to the specified recipients.
     * This function first updates the balances without emitting events, and then emits a Transfer event for each transfer.
     * @param recipients An array of recipient addresses.
     * @param amounts A bytes array where each 64-bit segment represents an amount to be transferred to the corresponding recipient.
     */
    function multiTransfer(address[] memory recipients, bytes memory amounts) external {
        // First, call multiSend to update balances without emitting events.
        _multiSend(recipients, amounts, true);
    }
}
