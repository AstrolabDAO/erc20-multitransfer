// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC20 } from "solady/src/tokens/ERC20.sol";

/// @title ERC20MultiTransfer
/// @author AstrolabDAO (https://github.com/AstrolabDAO/erc20-multitransfer/blob/main/src/ERC20MultiTransfer.sol)
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
     */
    function multiSend(address[] memory recipients, bytes memory amounts) public {

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
    function multiTransfer(address[] calldata recipients, bytes calldata amounts) public virtual {

        // First, call multiSend to update balances without emitting events.
        multiSend(recipients, amounts);

        /// @solidity memory-safe-assembly
        assembly {
            let length := calldataload(recipients.offset)
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let recipientOffset := add(recipients.offset, add(0x20, mul(i, 0x20)))
                let recipient := calldataload(recipientOffset)

                // Adjust to decode each 64-bit amount from the bytes array
                let amountOffset := add(add(amounts.offset, 32), mul(i, 8)) // Start reading after the 32-byte array length prefix
                let amount := shr(192, calldataload(amountOffset)) // Right-align the 64-bit amount

                // Emit the Transfer event for each transfer
                // Setup the event data in memory starting at position 0x00
                mstore(0x00, caller())      // Topic 1: from address
                mstore(0x20, recipient)     // Topic 2: to address
                mstore(0x40, amount)        // Data: value

                // log3 to emit the event with 3 topics (including the signature) and data
                log3(0x00, 0x60, shl(224, 0xddf252ad), caller(), recipient) // The Transfer event signature hash
            }
        }
    }
}
