# Solidity API

## YvTokenOracle

_Wrapper to quote V2 yVault Tokens like yvWETH, yvDAI, yvUSDC, yvUSDT
yVault Tokens list:  https://docs.yearn.finance/yearn-finance/yvaults/vault-tokens#v2-yvault-tokens_

### oracleRegistry

```solidity
contract IOracleRegistry oracleRegistry
```

### constructor

```solidity
constructor(address _vaultParameters, address _oracleRegistry) public
```

### assetToUsd

```solidity
function assetToUsd(address bearing, uint256 amount) public view returns (uint256)
```

### bearingToUnderlying

```solidity
function bearingToUnderlying(address bearing, uint256 amount) public view returns (address, uint256)
```

