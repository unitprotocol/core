# Solidity API

## WrappedShibaSwapLp

### isUnitProtocolWrappedAsset

```solidity
bytes32 isUnitProtocolWrappedAsset
```

_function for checks that asset is unitprotocol wrapped asset.
For wrapped assets must return keccak256("UnitProtocolWrappedAsset")_

### vault

```solidity
contract IVault vault
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

### userProxyImplementation

```solidity
address userProxyImplementation
```

### usersProxies

```solidity
mapping(address => contract WSSLPUserProxy) usersProxies
```

### allowedBoneLockersSelectors

```solidity
mapping(address => mapping(bytes4 => bool)) allowedBoneLockersSelectors
```

### feeReceiver

```solidity
address feeReceiver
```

### feePercent

```solidity
uint8 feePercent
```

### constructor

```solidity
constructor(address _vaultParameters, contract ITopDog _topDog, uint256 _topDogPoolId, address _feeReceiver) public
```

### setFeeReceiver

```solidity
function setFeeReceiver(address _feeReceiver) public
```

### setFee

```solidity
function setFee(uint8 _feePercent) public
```

### setAllowedBoneLockerSelector

```solidity
function setAllowedBoneLockerSelector(address _boneLocker, bytes4 _selector, bool _isAllowed) public
```

_in case of change bone locker to unsupported by current methods one_

### approveSslpToTopDog

```solidity
function approveSslpToTopDog() public
```

Approve sslp token to spend from user proxy (in case of change sslp)

### deposit

```solidity
function deposit(address _user, uint256 _amount) public
```

Get tokens from user, send them to TopDog, sent to user wrapped tokens

_only user or CDPManager could call this method_

### withdraw

```solidity
function withdraw(address _user, uint256 _amount) public
```

Unwrap tokens, withdraw from TopDog and send them to user

_only user or CDPManager could call this method_

### movePosition

```solidity
function movePosition(address _userFrom, address _userTo, uint256 _amount) public
```

Manually move position (or its part) to another user (for example in case of liquidation)

_Important! Use only with additional token transferring outside this function (example: liquidation - tokens are in vault and transferred by vault)
only CDPManager could call this method_

### pendingReward

```solidity
function pendingReward(address _user) public view returns (uint256)
```

Calculates pending reward for user. Not taken into account unclaimed reward from BoneLockers.
Use getClaimableRewardFromBoneLocker to calculate unclaimed reward from BoneLockers

### claimReward

```solidity
function claimReward(address _user) public
```

Claim pending direct reward for user.
Use claimRewardFromBoneLockers claim reward from BoneLockers

### getClaimableRewardFromBoneLocker

```solidity
function getClaimableRewardFromBoneLocker(address _user, contract IBoneLocker _boneLocker) public view returns (uint256)
```

Get claimable amount from BoneLocker

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _user | address | user address |
| _boneLocker | contract IBoneLocker | BoneLocker to check, pass zero address to check current |

### claimRewardFromBoneLocker

```solidity
function claimRewardFromBoneLocker(contract IBoneLocker _boneLocker, uint256 _maxBoneLockerRewardsAtOneClaim) public
```

Claim bones from BoneLockers
Since it could be a lot of pending rewards items parameters are used limit tx size

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _boneLocker | contract IBoneLocker | BoneLocker to claim, pass zero address to claim from current |
| _maxBoneLockerRewardsAtOneClaim | uint256 | max amount of rewards items to claim from BoneLocker, pass 0 to claim all rewards |

### getUnderlyingToken

```solidity
function getUnderlyingToken() public view returns (contract IERC20)
```

get SSLP token

_not immutable since it could be changed in TopDog_

### emergencyWithdraw

```solidity
function emergencyWithdraw() public
```

Withdraw tokens from topdog to user proxy without caring about rewards. EMERGENCY ONLY.
To withdraw tokens from user proxy to user use `withdrawToken`

### withdrawToken

```solidity
function withdrawToken(address _token, uint256 _amount) public
```

### readBoneLocker

```solidity
function readBoneLocker(address _user, address _boneLocker, bytes _callData) public view returns (bool success, bytes data)
```

### callBoneLocker

```solidity
function callBoneLocker(address _boneLocker, bytes _callData) public returns (bool success, bytes data)
```

### _transfer

```solidity
function _transfer(address sender, address recipient, uint256 amount) internal
```

_No direct transfers between users allowed since we store positions info in userInfo._

### _requireUserProxy

```solidity
function _requireUserProxy(address _user) internal view returns (contract WSSLPUserProxy userProxy)
```

### _getOrCreateUserProxy

```solidity
function _getOrCreateUserProxy(address _user, contract IERC20 sslpToken) internal returns (contract WSSLPUserProxy userProxy)
```

### createClone

```solidity
function createClone(address target) internal returns (address result)
```

_see https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol_

