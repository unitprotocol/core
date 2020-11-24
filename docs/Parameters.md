## `Parameters`






### `constructor(address payable _vault, address _foundation)` (public)

The address for an Ethereum contract is deterministically computed from the address of its creator (sender)
and how many transactions the creator has sent (nonce). The sender and nonce are RLP encoded and then
hashed with Keccak-256.
Therefore, the Vault address can be pre-computed and passed as an argument before deployment.*



### `setManager(address who, bool permit)` (external)

notice Only manager is able to call this function


Grants and revokes manager's status of any address


### `setFoundation(address newFoundation)` (external)

notice Only manager is able to call this function


Sets the foundation address


### `setCollateral(address asset, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 initialCollateralRatioValue, uint256 liquidationRatioValue, uint256 usdpLimit, uint256[] oracles, uint256 minColP, uint256 maxColP)` (external)

notice Only manager is able to call this function


Sets ability to use token as the main collateral


### `setInitialCollateralRatio(address asset, uint256 newValue)` (public)

notice Only manager is able to call this function


Sets the initial collateral ratio


### `setLiquidationRatio(address asset, uint256 newValue)` (public)

notice Only manager is able to call this function


Sets the liquidation ratio


### `setVaultAccess(address who, bool permit)` (external)

notice Only manager is able to call this function


Sets a permission for an address to modify the Vault


### `setStabilityFee(address asset, uint256 newValue)` (public)

notice Only manager is able to call this function


Sets the percentage of the year stability fee for a particular collateral


### `setLiquidationFee(address asset, uint256 newValue)` (public)

notice Only manager is able to call this function


Sets the percentage of the liquidation fee for a particular collateral


### `setColPartRange(address asset, uint256 min, uint256 max)` (public)

notice Only manager is able to call this function


Sets the percentage range of the COL token part for specific collateral token


### `setOracleType(uint256 _type, address asset, bool enabled)` (public)

notice Only manager is able to call this function


Enables/disables oracle types


### `setTokenDebtLimit(address asset, uint256 limit)` (public)

notice Only manager is able to call this function


Sets USDP limit for a specific collateral



