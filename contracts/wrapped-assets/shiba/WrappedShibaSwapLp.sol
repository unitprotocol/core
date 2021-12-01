// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../helpers/ReentrancyGuard.sol";
import "../../helpers/TransferHelper.sol";
import "../../Auth2.sol";
import "../../interfaces/wrapped-assets/IWrappedAsset.sol";
import "../../interfaces/wrapped-assets/ITopDog.sol";
import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";
import "../../helpers/UnitERC20.sol";

/**
 * @title ShibaSwapWrappedLp
 **/
contract WrappedShibaSwapLp is IWrappedAsset, Auth2, UnitERC20, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MULTIPLIER = 1e12;

    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;

    mapping(IBoneLocker => bool) public knownBoneLockers;
    IBoneLocker[] public knownBoneLockersArr;


    uint256 public lastKnownBonesBalance;
    uint256 public accBonePerShare; // Accumulated BONEs per share, times MULTIPLIER. See below.

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    address private immutable _deployer;
    bool private _isInitialised;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        // similar to TopDog contract https://etherscan.io/address/0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7
        // but we update accBonePerShare every transaction
        //
        // We do some fancy math here. Basically, any point in time, the amount of BONEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * accBonePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBonePerShare` gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    modifier updatePool() {
        _updatePool();
        _;
    }

    constructor(
        address _vaultParameters,
        IERC20 _boneToken,
        ITopDog _topDog,
        uint256 _topDogPoolId
    )
    Auth2(_vaultParameters)
    UnitERC20(IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).decimals())
    {
        boneToken = _boneToken;
        topDog = _topDog;
        topDogPoolId = _topDogPoolId;

        _deployer = msg.sender;
    }

    function init() public {
        require(msg.sender == _deployer);
        require(!_isInitialised);

        ISushiSwapLpToken sslpToken = ISushiSwapLpToken(address(getUnderlyingToken()));
        string memory token0Symbol = IERC20WithOptional(address(sslpToken.token0())).symbol();
        string memory token1Symbol = IERC20WithOptional(address(sslpToken.token1())).symbol();

        UnitERC20._initNameAndSymbol(
            string(
                abi.encodePacked(
                    "Wrapped by Unit ",
                    sslpToken.name(),
                    " ",
                    token0Symbol,
                    "-",
                    token1Symbol
                )
            ),
            string(
                abi.encodePacked(
                    "wu",
                    sslpToken.symbol(),
                    token0Symbol,
                    token1Symbol
                )
            )
        );

        _isInitialised = true;
    }

    /**
     * @notice Get tokens from user, send them to TopDog, sent to user wrapped tokens to deposit them in CDPManager
     * @dev only CDPManager could call this method
     */
    function deposit(address _userAddr, uint256 _amount) public override nonReentrant updatePool hasVaultAccess {
        UserInfo storage user = userInfo[_userAddr];
        _sendPendingRewardInternal(_userAddr, user.amount);

        if (_amount > 0) {
            IERC20 sslpToken = getUnderlyingToken();

            // get tokens from user, need approve of sslp tokens to pool
            TransferHelper.safeTransferFrom(address(sslpToken), _userAddr, address(this), _amount);
            user.amount = user.amount.add(_amount);

            // deposit them to TopDog
            sslpToken.approve(address(topDog), _amount);
            topDog.deposit(topDogPoolId, _amount);

            // wrapped tokens to user
            _mint(_userAddr, _amount);
        }
        user.rewardDebt = user.amount.mul(accBonePerShare).div(MULTIPLIER);
        emit Deposit(_userAddr, _amount);
    }

    /**
     * @notice Unwrap tokens, withdraw from TopDog and send them to user
     * @dev only CDPManager could call this method
     */
    function withdraw(address _userAddr, uint256 _amount) public override nonReentrant updatePool hasVaultAccess {
        UserInfo storage user = userInfo[_userAddr];
        require(user.amount >= _amount, "withdraw: not good");
        _sendPendingRewardInternal(_userAddr, user.amount);

        if (_amount > 0) {
            IERC20 sslpToken = getUnderlyingToken();
            user.amount = user.amount.sub(_amount);

            // get wrapped tokens from user
            _burn(_userAddr, _amount);

            // withdraw funds from TopDog
            topDog.withdraw(topDogPoolId, _amount);

            // send to user
            TransferHelper.safeTransfer(address(sslpToken), _userAddr, _amount);
        }

        user.rewardDebt = user.amount.mul(accBonePerShare).div(MULTIPLIER);
        if (totalSupply() == 0) {
            // on full withdrawal clear counters to distribute possible remainder next time
            accBonePerShare = 0;
            lastKnownBonesBalance = 0;
        }
        emit Withdraw(_userAddr, _amount);
    }

    /**
     * @notice Calculates pending reward for user. Not taken into account unclaimed reward from BoneLockers.
     * @notice Use getClaimableRewardAmountFromBoneLockers to calculate unclaimed reward from BoneLockers
     */
    function pendingReward(address _userAddr) public override view returns (uint256) {
        uint256 lpDeposited = totalSupply();
        if (lpDeposited == 0) {
            return 0;
        }

        UserInfo storage user = userInfo[_userAddr];
        if (user.amount == 0) {
            return 0;
        }

        uint256 currentBonesBalance = boneToken.balanceOf(address(this));
        uint256 pendingBones = topDog.pendingBone(topDogPoolId, address(this)).mul(topDog.rewardMintPercent()).div(100);
        uint256 addedBones = currentBonesBalance.sub(lastKnownBonesBalance).add(pendingBones);
        uint256 accBonePerShareTemp = accBonePerShare.add(addedBones.mul(MULTIPLIER).div(lpDeposited));

        return user.amount.mul(accBonePerShareTemp).div(MULTIPLIER).sub(user.rewardDebt);
    }

    /**
     * @notice Claim pending reward for user. User must manually claim reward from BoneLockers before call of this method
     * @notice Use claimRewardFromBoneLockers claim reward from BoneLockers
     */
    function claimReward() public override nonReentrant updatePool {
        UserInfo storage user = userInfo[msg.sender];
        _sendPendingRewardInternal(msg.sender, user.amount);
        user.rewardDebt = user.amount.mul(accBonePerShare).div(MULTIPLIER);
    }

    /**
     * @notice Calculates claimable from BoneLockers bones FOR THIS POOL, not for user. Reward grouped by BoneLockers
     * @param _firstBoneLockerIndex use 0 to calculate all rewards
     * @param _lastBoneLockerIndex use knownBoneLockersArrLength to calculate all rewards
     */
    function getClaimableRewardAmountFromBoneLockers(uint256 _firstBoneLockerIndex, uint256 _lastBoneLockerIndex)
    public view returns (uint256[] memory rewards)
    {
        require(_firstBoneLockerIndex <= _lastBoneLockerIndex);
        require(_lastBoneLockerIndex < knownBoneLockersArr.length);

        rewards = new uint256[](_lastBoneLockerIndex - _firstBoneLockerIndex + 1);

        for (uint256 i = _firstBoneLockerIndex; i <= _lastBoneLockerIndex; ++i) {
            rewards[i - _firstBoneLockerIndex] = knownBoneLockersArr[i].getClaimableAmount(address(this));
        }
    }

    /**
     * @notice Claim bones from BoneLockers FOR THIS POOL, not for user. User will get share from this amount
     * @notice Since it could be a lot of pending rewards items parameters are used limit tx size
     * @param _firstBoneLockerIndex use 0 to claim rewards from all BoneLockers
     * @param _lastBoneLockerIndex use knownBoneLockersArrLength to claim rewards from all BoneLockers
     * @param _maxBoneLockerRewardsAtOneClaim max amount of rewards items to claim from each BoneLocker, see getBoneLockerRewardsCount
     */
    function claimRewardFromBoneLockers(uint256 _firstBoneLockerIndex, uint256 _lastBoneLockerIndex, uint256 _maxBoneLockerRewardsAtOneClaim) public nonReentrant {
        require(_firstBoneLockerIndex <= _lastBoneLockerIndex);
        require(_lastBoneLockerIndex < knownBoneLockersArr.length);

        for (uint256 i = _firstBoneLockerIndex; i <= _lastBoneLockerIndex; ++i) {
            (uint256 left, uint256 right) = knownBoneLockersArr[i].getLeftRightCounters(address(this));
            if (right > left) {
                if (right - left > _maxBoneLockerRewardsAtOneClaim) {
                    right = left + _maxBoneLockerRewardsAtOneClaim;
                }
                knownBoneLockersArr[i].claimAll(right);
            }
        }
    }

    function knownBoneLockersArrLength() public view returns (uint256) {
        return knownBoneLockersArr.length;
    }

    function getBoneLockerRewardsCount(uint256 _firstBoneLockerIndex, uint256 _lastBoneLockerIndex)
    public view returns (uint256[] memory rewards)
    {
        require(_firstBoneLockerIndex <= _lastBoneLockerIndex);
        require(_lastBoneLockerIndex < knownBoneLockersArr.length);

        rewards = new uint256[](_lastBoneLockerIndex - _firstBoneLockerIndex + 1);

        for (uint256 locker_i = _firstBoneLockerIndex; locker_i <= _lastBoneLockerIndex; ++locker_i) {
            IBoneLocker locker = knownBoneLockersArr[locker_i];
            (uint256 left, uint256 right) = locker.getLeftRightCounters(address(this));
            uint i;
            for (i = left; i < right; i++) {
                (, uint256 ts,) = locker.lockInfoByUser(address(this), i);
                if (block.timestamp < ts.add(locker.lockingPeriod())) {
                    break;
                }
            }

            rewards[locker_i - _firstBoneLockerIndex] = i - left;
        }
    }

    /**
     * @notice get SSLP token
     * @dev not immutable since it could be changed in TopDog
     */
    function getUnderlyingToken() public override view returns (IERC20) {
        (IERC20 _sslpToken,,,) = topDog.poolInfo(topDogPoolId);

        return _sslpToken;
    }

    // Update reward variables to be up-to-date.
    function _updatePool() internal {
        uint256 lpDeposited = totalSupply();
        if (lpDeposited == 0) {
            return;
        }

        _claimBones();

        uint256 currentBonesBalance = boneToken.balanceOf(address(this));
        uint256 addedBones = currentBonesBalance.sub(lastKnownBonesBalance);
        lastKnownBonesBalance = currentBonesBalance;

        accBonePerShare = accBonePerShare.add(addedBones.mul(MULTIPLIER).div(lpDeposited));
    }

    function _claimBones() internal {
        // getting current reward (no separate methods)
        topDog.deposit(topDogPoolId, 0);

        // since bone locker could be replaced we're store all of them to claim all rewards
        IBoneLocker currentBoneLocker = topDog.boneLocker();
        if (!knownBoneLockers[currentBoneLocker]) {
            knownBoneLockers[currentBoneLocker] = true;
            knownBoneLockersArr.push(currentBoneLocker);
        }
    }

    function _sendPendingRewardInternal(address _userAddr, uint256 _userAmount) internal {
        if (_userAmount == 0) {
            return;
        }

        UserInfo storage user = userInfo[_userAddr];
        uint256 pending = user.amount.mul(accBonePerShare).div(MULTIPLIER).sub(user.rewardDebt);
        if (pending == 0) {
            return;
        }

        _safeBoneTransfer(_userAddr, pending);
        lastKnownBonesBalance = boneToken.balanceOf(address(this));
    }

    // Safe bone transfer function, just in case if rounding error causes pool to not have enough BONEs.
    function _safeBoneTransfer(address _to, uint256 _amount) internal {
        uint256 boneBal = boneToken.balanceOf(address(this));
        if (_amount > boneBal) {
            boneToken.transfer(_to, boneBal);
        } else {
            boneToken.transfer(_to, _amount);
        }
    }

    // get token for using in constructor
    function getSsLpToken(ITopDog _topDog, uint256 _topDogPoolId) private view returns (address) {
        (IERC20 _sslpToken,,,) = _topDog.poolInfo(_topDogPoolId);

        return address(_sslpToken);
    }
}
