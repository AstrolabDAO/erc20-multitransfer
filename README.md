<div align="center">
  <img border-radius="25px" max-height="250px" src="./banner.png" />
  <h1>ERC20 MultiTransfer</h1>
  <p>
    <strong>by <a href="https://astrolab.fi">Astrolab<a></strong>
  </p>
  <p>
    <!-- <a href="https://github.com/AstrolabDAO/erc20-multitransfer/actions"><img alt="Build Status" src="https://github.com/AstrolabDAO/erc20-multitransfer/actions/workflows/tests.yaml/badge.svg" /></a> -->
    <a href="https://opensource.org/licenses/MIT"><img alt="License" src="https://img.shields.io/github/license/AstrolabDAO/erc20-multitransfer?color=3AB2FF" /></a>
    <a href="https://discord.gg/PtAkTCwueu"><img alt="Discord Chat" src="https://img.shields.io/discord/984518964371673140"/></a>
    <a href="https://docs.astrolab.fi"><img alt="Astrolab Docs" src="https://img.shields.io/badge/astrolab_docs-F9C3B3" /></a>
  </p>
</div>

---

# Overview

`ERC20MultiTransfer` is a highly efficient, batch-transferrable ERC20 implementation designed for mass distribution.
1k+ transfers can fit in a single `multiSend` transaction on most EVMs.

Perfect use cases for this `MultiTransfer` are:
- Common airdrops
- Non-transferrable points distribution
- Reward distribution

`MultiTransfer` extends [Solady's optimized ERC20](https://github.com/Vectorized/solady/blob/main/src/tokens/ERC20.sol), this token aims to set a new standard for drop cost-efficiency.

## Features

- **High Efficiency**: Up to 10x cheaper than combining OpenZeppelin's ERC20 with multicall/multisend libraries or contracts.
- **Mass Distribution**: Capable of dropping tokens to 2,000+ addresses at once, with potential for 10,000+ depending on the EVM gas limit.
- **Event Emission Control**: Offers two modes of operation for transfers - with and without ERC20 `Transfer` event emissions, allowing for significant gas savings.

## Functions

### `multiSend`

Executes multiple token transfers without emitting `Transfer` events, optimizing gas consumption.

```solidity
function multiSend(address[] memory recipients, bytes memory amounts) external;
```

### `multiTransfer`

Performs multiple token transfers and emits a `Transfer` event for each transfer, adhering to ERC20 standards.

```solidity
function multiTransfer(address[] memory recipients, bytes memory amounts) external;
```

## Typical Gas Costs

| Action                    | Receivers | Gas Cost   |
|---------------------------|-----------|------------|
| `.multiTransfer()`        | 2         | 60,000     |
|                           | 10        | 240,000    |
|                           | 100       | 2,350,000  |
|                           | 500       | 12,500,000 |
|                           | 1000      | 16,800,000 |
|                           | 2000      | 32,000,000 |
| `.multiSend()`            | 2         | 57,000     |
| `.setBalanceSlotsUnsafe()`| 10        | 220,000    |
|                           | 100       | 2,150,000  |
|                           | 500       | 9,800,000  |
|                           | 1000      | 14,40,000  |
|                           | 2000      | 28,000,000 |

## Getting Started

### Testing

```bash
yarn test-hardhat
```

### Extending ERC20MultiTransfer

Implement your own ERC20 token by extending `ERC20MultiTransfer`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20MultiTransfer.sol";
import "solady/src/auth/Ownable.sol";

/// @title DropFrenCoin
/// @author Your Name/Team Name
contract DropFrenCoin is ERC20MultiTransfer, Ownable {
    constructor(string memory name, string memory symbol, uint8 decimals, address owner) 
        ERC20MultiTransfer(name, symbol, decimals) 
        Ownable(owner) 
    {}
}
```

## Disclaimer

This token, derived from Solady's audited ERC20 contract, adds un-audited features. The multiSend and multiTransfer functions, aimed at efficiency, may not fully comply with ERC20 standards due to possible omission of Transfer event emissions. We urge users and developers to perform extensive testing and security assessments. Feedback and improvements are appreciated!

---
