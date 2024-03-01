// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { ERC20 } from "solady/src/tokens/ERC20.sol";

/// @title ERC20MultiTransfer
/// @author AstrolabDAO (https://github.com/AstrolabDAO/erc20-multitransfer/blob/main/src/ERC20MultiTransfer.sol)
/// @author Solady (https://github.com/Vectorized/solady/blob/main/src/tokens/ERC20.sol)
abstract contract ERC20MultiTransfer is ERC20 {

    // redefinition of solady's private constants (should be internal for proper use)
    uint256 private constant _BALANCE_SLOT_SEED = 0x87a211a2;

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ADDON: MULTITRANSFER                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Allows the sender to transfer multiple amounts of tokens to multiple receivers
     * @param receivers An array of receiver addresses in memory
     * @param amounts A bytes array in memory where each 64-bit segment represents an amount to be transferred to the corresponding receiver
     * @param eventful A boolean indicating whether to emit Transfer events for each transfer
     */
    function _multiSend(address[] memory receivers, bytes memory amounts, bool eventful) internal {

        uint256 receiversCount = receivers.length;

        /// @solidity memory-safe-assembly
        assembly {
            let sender := caller()
            // Initialize totalAmount outside the loop
            let totalAmount := 0

            // Loop to calculate total amount to be sent and update receivers' balances
            for { let i := 0 } lt(i, receiversCount) { i := add(i, 1) } {
                // Directly load the amount from the amounts array in memory
                let amountOffset := add(amounts, add(mul(i, 0x20), 0x20)) // Start from the first amount, skipping the length field
                let amount := mload(amountOffset) // Use mul(i, 32) because mload expects byte offsets
                // Accumulate the total amount to be sent
                totalAmount := add(totalAmount, amount)

                // Load the receiver from the receivers array
                let receiver := mload(add(add(receivers, 0x20), mul(i, 0x20)))

                // Calculate receiver balance slot
                mstore(0x0c, _BALANCE_SLOT_SEED)
                mstore(0x00, receiver)
                let receiverBalanceSlot := keccak256(0x0c, 0x20)
                let receiverBalance := sload(receiverBalanceSlot)

                // Update receiver's balance
                sstore(receiverBalanceSlot, add(receiverBalance, amount))

                if eventful {
                    mstore(0x20, amount)
                    log3(0x20, 0x20, _TRANSFER_EVENT_SIGNATURE, sender, receiver)
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
     * @dev Computes the balance slots for a given array of addresses
     * @param addresses The array of addresses for which to compute the balance slots
     * @return balanceSlots The computed balance slots as a bytes array
     */
    function computeBalanceSlots(address[] memory addresses) external pure returns (bytes memory balanceSlots) {

        // balanceSlots = new bytes(addresses.length * 32); // Each slot is 32 bytes
        /// @solidity memory-safe-assembly
        assembly {
            // Load the length of the input addresses array
            let addressesLength := mload(addresses)
            // Calculate the total bytes needed for the output (32 bytes per address)
            let dataLength := mul(addressesLength, 0x20)

            // Allocate memory for the bytes array, including its length prefix
            balanceSlots := mload(0x40) // Use the free memory pointer
            mstore(balanceSlots, dataLength) // Store the length of the bytes array at the beginning
            let slotsData := add(balanceSlots, 0x20) // Calculate the start of the bytes array data

            // Update the free memory pointer
            let newFreePtr := add(slotsData, dataLength)
            mstore(0x40, newFreePtr)

            // Iterate over each address to compute and store its balance slot hash
            for { let i := 0 } lt(i, addressesLength) { i := add(i, 0x01) } {
                let addr := mload(add(addresses, add(mul(i, 0x20), 0x20))) // Load the current address

                // Prepare the seed and address in memory for hashing
                let hashDataPtr := mload(0x40) // Temporarily use the space after the last allocation
                mstore(add(hashDataPtr, 0x0c), _BALANCE_SLOT_SEED) // Place the seed starting at the 12th byte
                mstore(hashDataPtr, addr) // Place the address, partially overwriting the seed

                // Compute the hash
                let hash := keccak256(add(hashDataPtr, 0x0c), 0x20) // Hash the data starting from the 12th byte

                // Store the hash in the allocated bytes array
                mstore(add(slotsData, mul(i, 0x20)), hash)
            }
        }
    }

    /**
     * @dev Executes multiple transfers of tokens to the specified receivers
     * This function first updates the balances without emitting events, and then emits a Transfer event for each transfer
     * @param receivers An array of receiver addresses
     * @param amounts A bytes array where each 64-bit segment represents an amount to be transferred to the corresponding receiver
     */
    function multiSend(address[] memory receivers, bytes memory amounts) external {
        _multiSend(receivers, amounts, false);
    }

    /**
     * @dev Executes multiple transfers of tokens to the specified receivers
     * This function first updates the balances without emitting events, and then emits a Transfer event for each transfer
     * @param receivers An array of receiver addresses
     * @param amounts A bytes array where each 64-bit segment represents an amount to be transferred to the corresponding receiver
     */
    function multiTransfer(address[] memory receivers, bytes memory amounts) external {
        // First, call multiSend to update balances without emitting events
        _multiSend(receivers, amounts, true);
    }

    /**
     * @dev Executes batch transfers using pre-compiled balance slots
     * This function updates balances based on pre-compiled slots and amounts without emitting events
     * @param balanceSlots A bytes array containing the pre-compiled balance slots for each receiver
     * @param amounts A bytes array where each 64-bit segment represents an amount to be transferred
     */
    function _addToBalanceSlotsUnsafe(bytes memory balanceSlots, bytes memory amounts) internal {

        uint256 slotsLength = balanceSlots.length / 32; // Each slot is 32 bytes

        assembly {
            let sender := caller()
            let totalAmount := 0

            for { let i := 0 } lt(i, slotsLength) { i := add(i, 1) } {
                // Calculate the offset for the current amount (64-bit) and slot (256-bit)
                let amountOffset := add(amounts, add(mul(i, 0x20), 0x20)) // Start from the first amount, skipping the length field
                let slotOffset := add(balanceSlots, add(mul(i, 0x20), 0x20)) // Start from the first slot, skipping the length field

                let amount := mload(amountOffset) // Use mul(i, 32) because mload expects byte offsets
                // amount := and(shr(192, amount), 0xFFFFFFFFFFFFFFFF)
                totalAmount := add(totalAmount, amount) // Update totalAmount

                let balanceSlot := mload(slotOffset) // Load the current balance slot
                let currentBalance := sload(balanceSlot) // Get the current balance from the slot
                sstore(balanceSlot, add(currentBalance, amount)) // Update the balance in the slot
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
}
