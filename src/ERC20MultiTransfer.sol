// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC20 } from "./ERC20.sol";

/// @title ERC20MultiTransfer
/// @author AstrolabDAO (https://github.com/AstrolabDAO/erc20-multitransfer/blob/main/src/ERC20MultiTransfer.sol)
abstract contract ERC20MultiTransfer is ERC20 {

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDON: MULTITRANSFER                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Allows the sender to transfer multiple amounts of tokens to multiple recipients.
     * @param recipients An array of recipient addresses.
     * @param amounts An array of corresponding amounts to be transferred to each recipient.
     */
    function multiSend(address[] calldata recipients, uint256[] calldata amounts) public virtual {
        /// @solidity memory-safe-assembly
        assembly {
            let sender := caller()
            let recipientsLength := calldataload(recipients.offset)
            let amountsLength := calldataload(amounts.offset)

            // Ensure recipients and amounts arrays are of equal length
            if iszero(eq(recipientsLength, amountsLength)) {
                revert(0, 0)
            }

            // Calculate total amount to be sent
            let totalAmount := 0
            for { let i := 0 } lt(i, recipientsLength) { i := add(i, 1) } {
                let amount := calldataload(add(amounts.offset, add(0x20, mul(i, 0x20))))
                totalAmount := add(totalAmount, amount)
            }

            // Calculate sender balance slot and check balance
            mstore(0x0c, _BALANCE_SLOT_SEED)
            mstore(0x00, sender)
            let senderBalanceSlot := keccak256(0x0c, 0x20)
            let senderBalance := sload(senderBalanceSlot)
            if lt(senderBalance, totalAmount) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }

            // Update sender's balance
            sstore(senderBalanceSlot, sub(senderBalance, totalAmount))

            // Update recipients' balances
            for { let i := 0 } lt(i, recipientsLength) { i := add(i, 1) } {
                let recipient := calldataload(add(recipients.offset, add(0x20, mul(i, 0x20))))
                let amount := calldataload(add(amounts.offset, add(0x20, mul(i, 0x20))))

                // Calculate recipient balance slot
                mstore(0x0c, _BALANCE_SLOT_SEED)
                mstore(0x00, recipient)
                let recipientBalanceSlot := keccak256(0x0c, 0x20)
                let recipientBalance := sload(recipientBalanceSlot)

                // Update recipient's balance
                sstore(recipientBalanceSlot, add(recipientBalance, amount))
            }
        }
    }

    /**
     * @dev Executes multiple transfers of tokens to the specified recipients.
     * This function first updates the balances without emitting events, and then emits a Transfer event for each transfer.
     * @param recipients An array of recipient addresses.
     * @param amounts An array of corresponding amounts to be transferred.
     */
    function multiTransfer(address[] calldata recipients, uint256[] calldata amounts) public virtual {

        // First, call multiSend to update balances without emitting events.
        multiSend(recipients, amounts);
        /// @solidity memory-safe-assembly
        assembly {
            // Loop to emit Transfer events for each transfer.
            let length := calldataload(recipients.offset)
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let recipientOffset := add(recipients.offset, add(0x20, mul(i, 0x20)))
                let recipient := calldataload(recipientOffset)
                let amountOffset := add(amounts.offset, add(0x20, mul(i, 0x20)))
                let amount := calldataload(amountOffset)

                // Emit the Transfer event for each transfer
                // Setup the event data in memory starting at position 0x00
                mstore(0x00, _TRANSFER_EVENT_SIGNATURE) // Event Signature
                mstore(0x20, caller()) // Topic 1: from address
                mstore(0x40, recipient) // Topic 2: to address
                mstore(0x60, amount) // Data: value

                // log3(start position of data, size of data, topic1, topic2, topic3)
                // Since we're logging one word (32 bytes) of data (the amount),
                // and two topics (from and to addresses), the data starts at 0x60 and is 0x20 bytes long.
                log3(0x00, 0x60, _TRANSFER_EVENT_SIGNATURE, caller(), recipient)
            }
        }
    }
}
