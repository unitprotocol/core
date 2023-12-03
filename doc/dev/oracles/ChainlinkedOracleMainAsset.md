# ChainlinkedOracleMainAsset Smart Contract Technical Overview

## Contract Overview
`ChainlinkedOracleMainAsset` is a contract designed for price feed integration with Chainlink. It enables the conversion of token values to USD and ETH using Chainlink's price feeds.

## Key Features

### 1. Libraries
- Uses `SafeMath` for safe mathematical operations.

### 2. State Variables
- `usdAggregators`: Maps token addresses to their corresponding Chainlink USD aggregators.
- `ethAggregators`: Maps token addresses to their Chainlink ETH aggregators.
- `Q112`: A constant representing 2^112, used for fixed-point arithmetic.
- `USD_TYPE` and `ETH_TYPE`: Constants to distinguish between USD and ETH aggregator types.
- `WETH`: Immutable address of the WETH token.

### 3. Events
- `NewAggregator`: Emitted when a new aggregator is set for a token.

### 4. Constructor
Initializes the contract with token addresses, USD aggregators, ETH aggregators, WETH address, and VaultParameters address.

### 5. Functions
- `setAggregators`: Sets USD and ETH aggregators for tokens. Only callable by the manager.
- `assetToUsd`: Converts an asset amount to its USD value. Supports both direct USD and indirect via ETH conversion.
- `_assetToUsd`: Internal function to convert asset to USD for assets with direct USD Chainlink aggregator.
- `assetToEth`: Converts an asset amount to its ETH value. Supports direct ETH conversion and indirect via USD.
- `ethToUsd`: Converts an ETH amount to its USD value using Chainlink.
- `usdToEth`: Converts a USD amount to its ETH value using Chainlink.

### 6. Modifiers
- `onlyManager`: Restricts function access to the manager.
- `Auth`: Inherits from the `Auth` contract, providing basic authorization control functions.

### 7. Security Considerations
- Ensures Chainlink data freshness by requiring the latest price update to be within a defined time window.
- Protects against negative price returns from Chainlink.
- Utilizes `SafeMath` for safe arithmetic operations to prevent overflows and underflows.

### 8. External Dependencies
- Relies on Chainlink's price feeds to provide asset price data.
- Depends on the `VaultParameters` contract for authorization checks.

## Conclusion
`ChainlinkedOracleMainAsset` serves as a bridge between Chainlink's price feeds and the Unit Protocol system. It provides critical functionality for converting asset values between USD, ETH, and other ERC20 tokens, ensuring accurate and up-to-date pricing information is used in the protocol's operations.
