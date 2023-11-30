# Solidity API

## Auth2

_Manages USDP's system access
copy of Auth from VaultParameters.sol but with immutable vaultParameters for saving gas_

### vaultParameters

```solidity
contract VaultParameters vaultParameters
```

### constructor

```solidity
constructor(address _parameters) public
```

### onlyManager

```solidity
modifier onlyManager()
```

### hasVaultAccess

```solidity
modifier hasVaultAccess()
```

### onlyVault

```solidity
modifier onlyVault()
```

