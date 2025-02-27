# Stacks AMM DEX Smart Contract

A decentralized exchange (DEX) smart contract for the Stacks blockchain implementing an Automated Market Maker (AMM) model similar to Uniswap.

## Overview

This smart contract implements a decentralized exchange with the following features:

- Creation of liquidity pools for token pairs
- Adding/removing liquidity to existing pools
- Swapping tokens with configurable fees
- Constant product market maker formula (x * y = k)

## Key Functions

### Read-Only Functions

- `get-pool-info`: Retrieve information about a specific liquidity pool
- `quote-x-for-y`: Get a price quote for swapping token X for token Y

### Public Functions

- `create-pool`: Create a new liquidity pool for a token pair
- `add-liquidity`: Add liquidity to an existing pool
- `remove-liquidity`: Remove liquidity from a pool
- `swap-x-for-y`: Swap token X for token Y
- `swap-y-for-x`: Swap token Y for token X

## Technical Features

- Non-recursive square root implementation using Newton's method
- Configurable swap fees in basis points (e.g., 30 = 0.3%)
- Slippage protection for liquidity providers and traders
- Constant product formula (x * y = k) for price calculation

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not token owner |
| u102 | Insufficient balance |
| u103 | Zero amount not allowed |
| u104 | Pool already exists |
| u105 | Pool not found |
| u106 | Slippage too high |
| u107 | Invalid swap fee |
| u108 | Invalid token |

## Usage Examples

### Creating a Pool

```clarity
(contract-call? .dex create-pool "TOKEN-X" "TOKEN-Y" u1000000 u1000000 u30)
```

### Adding Liquidity

```clarity
(contract-call? .dex add-liquidity "TOKEN-X" "TOKEN-Y" u100000 u100000 u99000)
```

### Removing Liquidity

```clarity
(contract-call? .dex remove-liquidity "TOKEN-X" "TOKEN-Y" u10000 u9900 u9900)
```

### Swapping Tokens

```clarity
(contract-call? .dex swap-x-for-y "TOKEN-X" "TOKEN-Y" u10000 u9900)
```

## Notes

This implementation is a basic AMM DEX. In a production environment, you would need to:

1. Add proper token contract integrations for actual token transfers
2. Add additional safety features like reentrancy guards
3. Consider adding flash loan prevention mechanisms
4. Add events for better off-chain tracking
5. Implement proper governance mechanisms