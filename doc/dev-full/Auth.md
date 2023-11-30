# Solidity API

## Auth

_Manages USDP's system access_

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

