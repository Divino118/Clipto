# Clipto NFT Marketplace Smart Contract

## Overview
Clipto is a decentralized NFT marketplace built on the Stacks blockchain. It allows users to mint, list, buy, and sell NFTs with built-in royalty support. The contract includes features like price controls, cooling periods, and administrative functions for platform management.

## Features
- NFT minting with customizable royalties
- Marketplace listing and delisting
- Price updates with cooldown period
- Built-in royalty system
- Administrative controls
- Pause/unpause functionality
- Event logging for all major operations

## Technical Specifications
- Platform: Stacks Blockchain
- Language: Clarity
- Contract Type: Non-Fungible Token (NFT) Marketplace
- Token Standard: Clarity NFT Standard

## Constants
- Minimum Price: 1 microSTX
- Maximum Price: 1,000,000,000 microSTX (1 billion)
- Maximum Royalty: 20%
- Price Change Cooldown: 24 hours (86400 blocks)
- Maximum Token ID: 1,000,000

## Core Functions

### NFT Management
- `clipto-mint`: Mint new NFTs with royalty settings
- `clipto-transfer`: Transfer NFTs between users

### Marketplace Operations
- `clipto-list`: List NFTs for sale
- `clipto-delist`: Remove NFTs from marketplace
- `clipto-update-price`: Update listing price (subject to cooldown)
- `clipto-purchase`: Purchase listed NFTs

### Administrative Functions
- `set-contract-admin`: Set new contract administrator
- `toggle-contract-pause`: Pause/unpause contract operations

### Read-Only Functions
- `clipto-is-listed`: Check if an NFT is listed
- `clipto-get-listing`: Get listing details
- `clipto-calculate-royalty`: Calculate royalty amount
- `clipto-get-royalty`: Get royalty information

## Error Codes
```
u100: NFT already exists
u101: Not NFT owner
u102: Insufficient funds
u103: NFT not listed
u104: Unauthorized transfer
u105: NFT doesn't exist
u106: Invalid owner
u107: Invalid price
u108: Transfer failed
u109: Invalid token state
u110: Invalid royalty
u111: Unauthorized
u112: Self transfer not allowed
u113: Invalid price
u114: Cooldown active
u115: Contract paused
u116: Already listed
u117: Invalid token ID
u118: Invalid admin
```

## Event Logging
The contract emits events for all major operations:
- NFT minting
- Listing creation/updates
- Sales
- Transfers
- Administrative changes

## Security Features
- Input validation for all functions
- Price bounds checking
- Royalty percentage limits
- Cooldown period for price changes
- Admin access controls
- Pause functionality for emergencies
- Self-transfer prevention
- Token ID range validation

## Usage Examples

### Minting an NFT
```clarity
(contract-call? .clipto-marketplace clipto-mint u1 u10)
;; Mints NFT with ID 1 and 10% royalty
```

### Listing an NFT
```clarity
(contract-call? .clipto-marketplace clipto-list u1 u1000000)
;; Lists NFT with ID 1 for 1 STX
```

### Purchasing an NFT
```clarity
(contract-call? .clipto-marketplace clipto-purchase u1)
;; Purchases NFT with ID 1
```

## Setup Instructions

1. Deploy the contract to the Stacks blockchain
2. Initialize contract ownership (deployer becomes initial admin)
3. Begin minting and listing NFTs

## Limitations

- Maximum token ID of 1,000,000
- Fixed 24-hour cooldown period
- Maximum 20% royalty
- Single admin role
