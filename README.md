
# Marble - Omnichain Tokenbound Subscription Protocol

## Introduction

This project implements an omnichain subscription system controlled by NFTs, utilizing ERC6551 tokenbound accounts and LayerZero V2 for cross-chain communication. It allows creators to manage subscriptions across multiple blockchains from a single NFT on a base chain.

## Architecture Overview

```mermaid
graph TB
    subgraph "Base Chain"
        A[CreatorNFT Contract]
        B[Creator NFT]
        F[LayerZero Endpoint]
        A -->|Mints| B
        A <-->|Uses| F
    end
    
    subgraph "Chain A"
        G[CustomRegistry A]
        C[PaymentModule A]
        G -->|Deploys| C
    end
    
    subgraph "Chain B"
        H[CustomRegistry B]
        D[PaymentModule B]
        H -->|Deploys| D
    end
    
    subgraph "Chain C"
        I[CustomRegistry C]
        E[PaymentModule C]
        I -->|Deploys| E
    end
    
    B -->|Controls| C
    B -->|Controls| D
    B -->|Controls| E
    
    F <-->|_lzSend| G
    F <-->|_lzSend| H
    F <-->|_lzSend| I
    
    J[User] -->|Mints/Manages| A
    J -->|Subscribes| C
    J -->|Subscribes| D
    J -->|Subscribes| E
   ```
    
## Key Components

1. **CreatorNFT Contract**: 
   - Deployed on the base chain
   - Manages NFT minting and controls cross-chain operations
   - Initiates deployment of PaymentModules on other chains

2. **PaymentModule Contract**:
   - Implements ERC6551 Account interface
   - Manages subscriptions on its specific chain
   - Can be deployed on multiple chains

3. **CustomRegistry Contract**:
   - Deployed on each chain
   - Handles PaymentModule deployment and cross-chain message processing
   - Inherits from ERC6551Registry for tokenbound account creation

4. **LayerZero Integration**:
   - Facilitates cross-chain communication
   - Enables omnichain subscription management


## Key Features

1. **Single Point of Control**: CreatorNFT on the base chain controls all PaymentModules across different chains.
2. **Unified Subscription Management**: Users manage subscriptions on any chain through the CreatorNFT contract.
3. **Cross-Chain Subscription Validation**: Services can validate subscriptions on any chain via the CreatorNFT contract.
4. **Flexible Deployment**: Creators can deploy PaymentModules to new chains as needed.

## Subscription Tier Examples

Users can subscribe to these different tiers using the `subscribe` function:

- Monthly Subscription:

```solidity
createTier(1 ether, 30 days);
```

This creates a tier with a price of 1 ETH and a duration of 30 days.

- Quarterly Subscription:

```solidity
createTier(2.5 ether, 90 days);
```



- Annual Subscription:

```solidity
createTier(7.5 ether, 365 days);
```



- Lifetime Subscription:

```solidity
createTier(12.5 ether, 36500 days);
```

This creates a tier with a price of 12.5 ETH and a duration of 100 years (effectively lifetime).

## Future Improvement Ideas

1. **Multi-Token Support**: Enable subscriptions to be purchased with various ERC20 tokens across different chains with price oracle integration.

2. **Subscription Streaming**: Integrate with protocols like Sablier to enable real-time streaming of subscription payments.

3. **Automated Subscription Management**: Integrate Chainlink Keepers or Gelato for automated subscription renewals and cancellations.

