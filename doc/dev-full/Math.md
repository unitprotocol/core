# Solidity API

## Math

_Standard math utilities missing in the Solidity language._

### max

```solidity
function max(uint256 a, uint256 b) internal pure returns (uint256)
```

_Returns the largest of two numbers._

### min

```solidity
function min(uint256 a, uint256 b) internal pure returns (uint256)
```

_Returns the smallest of two numbers._

### average

```solidity
function average(uint256 a, uint256 b) internal pure returns (uint256)
```

_Returns the average of two numbers. The result is rounded towards
zero._

### sqrt

```solidity
function sqrt(uint256 x) internal pure returns (uint256 y)
```

_babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)_

