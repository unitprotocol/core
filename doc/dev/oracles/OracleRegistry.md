# OracleRegistry Smart Contract Technical Overview

## Contract Overview
The `OracleRegistry` contract is part of the Unit Protocol system, serving as a registry for oracles. It maps assets to their respective oracle types and oracle addresses, providing a central point to manage and access oracle information.

## Key Features

### 1. Data Structures
- `Oracle`: A struct containing oracle type and oracle address.
- Mappings:
  - `oracleTypeByAsset`: Maps asset addresses to oracle type IDs.
  - `oracleByType`: Maps oracle type IDs to oracle addresses.
  - `oracleTypeByOracle`: Maps oracle addresses to oracle type IDs.
- Arrays:
  - `keydonixOracleTypes`: Stores oracle type IDs specific to Keydonix oracles.

### 2. State Variables
- `maxOracleType`: Tracks the maximum oracle type ID used.
- `WETH`: Immutable address of the Wrapped Ether (WETH) token.

### 3. Events
- `AssetOracle`: Emitted when an asset's oracle type is set or unset.
- `OracleType`: Emitted when an oracle type is set or unset.
- `KeydonixOracleTypes`: Emitted when Keydonix oracle types are set.

### 4. Modifiers
- `validAddress`: Ensures the provided address is not the zero address.
- `validType`: Ensures the provided oracle type is non-zero.
- `onlyManager`: Ensures that only a manager can call certain functions.

### 5. Constructor
- Initializes the contract with the `vaultParameters` and `WETH` addresses.

### 6. Key Functions
- `setKeydonixOracleTypes`: Sets the oracle types specific to Keydonix oracles.
- `setOracle`: Associates an oracle address with an oracle type.
- `unsetOracle`: Removes an oracle type and its associated oracle address.
- `setOracleTypeForAsset`: Sets the oracle type for a specific asset.
- `setOracleTypeForAssets`: Sets the oracle type for multiple assets.
- `unsetOracleForAsset`: Removes the oracle type association for an asset.
- `unsetOracleForAssets`: Removes the oracle type associations for multiple assets.
- `getOracles`: Retrieves all registered oracles.
- `getKeydonixOracleTypes`: Retrieves all Keydonix oracle types.
- `oracleByAsset`: Retrieves the oracle address for a given asset.

### 7. Access Control
- Managed by "managers" who have the authority to modify oracle settings.
- Leverages `Auth` and `VaultParameters` for access control mechanisms.

### 8. Error Handling
- Performs checks to ensure valid oracle types and addresses are provided.
- Reverts transactions with invalid inputs or unauthorized access.

## Conclusion
`OracleRegistry` is a critical component of the Unit Protocol ecosystem, offering a structured and secure way to manage oracles for different assets. It enables dynamic oracle management, ensuring flexibility and up-to-date oracle information for the protocol's operations.
