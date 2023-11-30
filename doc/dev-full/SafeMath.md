# Solidity API

## SafeMath

_Math operations with safety checks that throw on error_

### mul

```solidity
function mul(uint256 a, uint256 b) internal pure returns (uint256 c)
```

_Multiplies two numbers, throws on overflow._

### div

```solidity
function div(uint256 a, uint256 b) internal pure returns (uint256)
```

_Integer division of two numbers, truncating the quotient._

### sub

```solidity
function sub(uint256 a, uint256 b) internal pure returns (uint256)
```

_Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend)._

### add

```solidity
function add(uint256 a, uint256 b) internal pure returns (uint256 c)
```

_Adds two numbers, throws on overflow._

