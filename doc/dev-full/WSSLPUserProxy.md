# Solidity API

## WSSLPUserProxy

### manager

```solidity
address manager
```

### topDog

```solidity
contract ITopDog topDog
```

### topDogPoolId

```solidity
uint256 topDogPoolId
```

### boneToken

```solidity
contract IERC20 boneToken
```

### onlyManager

```solidity
modifier onlyManager()
```

### constructor

```solidity
constructor(contract ITopDog _topDog, uint256 _topDogPoolId) public
```

### approveSslpToTopDog

```solidity
function approveSslpToTopDog(contract IERC20 _sslpToken) public
```

_in case of change sslp_

### deposit

```solidity
function deposit(uint256 _amount) public
```

### withdraw

```solidity
function withdraw(contract IERC20 _sslpToken, uint256 _amount, address _sentTokensTo) public
```

### pendingReward

```solidity
function pendingReward(address _feeReceiver, uint8 _feePercent) public view returns (uint256)
```

### claimReward

```solidity
function claimReward(address _user, address _feeReceiver, uint8 _feePercent) public
```

### _calcFee

```solidity
function _calcFee(uint256 _amount, address _feeReceiver, uint8 _feePercent) internal pure returns (uint256 amountWithoutFee, uint256 fee)
```

### _sendAllBonesToUser

```solidity
function _sendAllBonesToUser(address _user, address _feeReceiver, uint8 _feePercent) internal
```

### _sendBonesToUser

```solidity
function _sendBonesToUser(address _user, uint256 _amount, address _feeReceiver, uint8 _feePercent) internal
```

### getClaimableRewardFromBoneLocker

```solidity
function getClaimableRewardFromBoneLocker(contract IBoneLocker _boneLocker, address _feeReceiver, uint8 _feePercent) public view returns (uint256)
```

### claimRewardFromBoneLocker

```solidity
function claimRewardFromBoneLocker(address _user, contract IBoneLocker _boneLocker, uint256 _maxBoneLockerRewardsAtOneClaim, address _feeReceiver, uint8 _feePercent) public
```

### emergencyWithdraw

```solidity
function emergencyWithdraw() public
```

### withdrawToken

```solidity
function withdrawToken(address _token, address _user, uint256 _amount, address _feeReceiver, uint8 _feePercent) public
```

### readBoneLocker

```solidity
function readBoneLocker(address _boneLocker, bytes _callData) public view returns (bool success, bytes data)
```

### callBoneLocker

```solidity
function callBoneLocker(address _boneLocker, bytes _callData) public returns (bool success, bytes data)
```

### getDepositedAmount

```solidity
function getDepositedAmount() public view returns (uint256 amount)
```

