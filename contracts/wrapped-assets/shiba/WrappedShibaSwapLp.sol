// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../helpers/ReentrancyGuard.sol";
import "../../helpers/TransferHelper.sol";
import "../../Auth2.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IERC20WithOptional.sol";
import "../../interfaces/wrapped-assets/IWrappedAsset.sol";
import "../../interfaces/wrapped-assets/ITopDog.sol";
import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";

/**
 * @title ShibaSwapWrappedLp
 **/
contract WrappedShibaSwapLp is IWrappedAsset, Auth2, ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MULTIPLIER = 1e12;

    IVault public immutable vault;
    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;

    uint256 public lastKnownBonesBalance;
    uint256 public accBonePerShare; // Accumulated BONEs per share, times MULTIPLIER. See below.

    uint256 public feePercent = 10;
    uint256 public constant FEE_DENOMINATOR = 100;
    address public feeReceiver;

    // Reward debt. See explanation below.
    // similar to TopDog contract https://etherscan.io/address/0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7
    // but we update accBonePerShare every transaction
    //
    // We do some fancy math here. Basically, any point in time, the amount of BONEs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (totalBalanceOf(user) * accBonePerShare) - rewardDebt[user]
    //
    // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    //   1. The pool's `accBonePerShare` gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `totalBalanceOf` gets updated (since minted/burned tokens for user)
    //   4. User's `rewardDebt` gets updated.
    //
    // on transfers balanceOf + deposited to vault = const
    mapping(address => uint256) public rewardDebts;

    modifier updatePool() {
        _updatePool();
        _;
    }

    constructor(
        address _vaultParameters,
        ITopDog _topDog,
        uint256 _topDogPoolId,
        address _feeReceiver
    )
    Auth2(_vaultParameters)
    ERC20(
        string(
            abi.encodePacked(
                "Wrapped by Unit ",
                getSsLpTokenName(_topDog, _topDogPoolId),
                " ",
                getSsLpTokenToken0Symbol(_topDog, _topDogPoolId),
                "-",
                getSsLpTokenToken1Symbol(_topDog, _topDogPoolId)
            )
        ),
        string(
            abi.encodePacked(
                "wu",
                getSsLpTokenSymbol(_topDog, _topDogPoolId),
                getSsLpTokenToken0Symbol(_topDog, _topDogPoolId),
                getSsLpTokenToken1Symbol(_topDog, _topDogPoolId)
            )
        )
    )
    {
        boneToken = _topDog.bone();
        topDog = _topDog;
        topDogPoolId = _topDogPoolId;
        vault = IVault(VaultParameters(_vaultParameters).vault());

        _setupDecimals(IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).decimals());

        feeReceiver = _feeReceiver;
    }

    /**
     * @notice Approves for TopDog contract to transfer tokens from this ~forever
     * @dev only manager could call this method
     */
    function approveSslpToTopdog() public onlyManager {
        getUnderlyingToken().approve(address(topDog), uint256(-1));
    }

    function setFeeReceiver(address _feeReceiver) public onlyManager {
        feeReceiver = _feeReceiver;

        emit FeeReceiverChanged(_feeReceiver);
    }

    function setFee(uint256 _feePercent) public onlyManager {
        require(_feePercent <= 50, "Unit Protocol Wrapped Assets: INVALID_FEE");
        feePercent = _feePercent;

        emit FeeChanged(_feePercent);
    }

    /**
     * @notice Get tokens from user, send them to TopDog, sent to user wrapped tokens
     * @dev only user or CDPManager could call this method
     */
    function deposit(address _userAddr, uint256 _amount) public override nonReentrant updatePool {
        require(msg.sender == _userAddr || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        uint256 userBalance = totalBalanceOf(_userAddr);
        _sendPendingRewardInternal(_userAddr, userBalance);

        if (_amount > 0) {
            IERC20 sslpToken = getUnderlyingToken();

            // get tokens from user, need approve of sslp tokens to pool
            TransferHelper.safeTransferFrom(address(sslpToken), _userAddr, address(this), _amount);

            // deposit them to TopDog
            topDog.deposit(topDogPoolId, _amount);

            // wrapped tokens to user
            _mint(_userAddr, _amount);
        }
        rewardDebts[_userAddr] = (userBalance.add(_amount)).mul(accBonePerShare).div(MULTIPLIER);
        emit Deposit(_userAddr, _amount);
    }

    /**
     * @notice Unwrap tokens, withdraw from TopDog and send them to user
     * @dev only user or CDPManager could call this method
     */
    function withdraw(address _userAddr, uint256 _amount) public override nonReentrant updatePool {
        require(msg.sender == _userAddr || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        uint256 userBalance = totalBalanceOf(_userAddr);
        require(userBalance >= _amount, "Unit Protocol Wrapped Assets: INSUFFICIENT_AMOUNT");
        _sendPendingRewardInternal(_userAddr, userBalance);

        if (_amount > 0) {
            IERC20 sslpToken = getUnderlyingToken();

            // get wrapped tokens from user
            _burn(_userAddr, _amount);

            // withdraw funds from TopDog
            topDog.withdraw(topDogPoolId, _amount);

            // send to user
            TransferHelper.safeTransfer(address(sslpToken), _userAddr, _amount);
        }

        rewardDebts[_userAddr] = (userBalance.sub(_amount)).mul(accBonePerShare).div(MULTIPLIER);
        if (totalSupply() == 0) {
            // on full withdrawal clear counters to distribute possible remainder next time
            accBonePerShare = 0;
            lastKnownBonesBalance = 0;
        }
        emit Withdraw(_userAddr, _amount);
    }

    /**
     * @notice Manually move position (or its part) to another user (for example in case of liquidation)
     * @dev Important! Use only with additional token transferring outside this function (example: liquidation - tokens are in vault and transferred by vault)
     * @dev only CDPManager could call this method
     */
    function movePosition(address _userAddrFrom, address _userAddrTo, uint256 _amount) public override nonReentrant updatePool hasVaultAccess {
        if (_userAddrFrom == _userAddrTo) {
            _claimRewardInternal(_userAddrFrom);
            return;
        }

        uint256 userFromBalance = totalBalanceOf(_userAddrFrom);
        require(userFromBalance >= _amount, "Unit Protocol Wrapped Assets: INSUFFICIENT_AMOUNT");
        _sendPendingRewardInternal(_userAddrFrom, userFromBalance);

        uint256 userToBalance = totalBalanceOf(_userAddrTo);
        _sendPendingRewardInternal(_userAddrTo, userToBalance);

        // tokens must be transferred outside. We suppose it
        rewardDebts[_userAddrFrom] = (userFromBalance.sub(_amount)).mul(accBonePerShare).div(MULTIPLIER);
        rewardDebts[_userAddrTo] = (userToBalance.add(_amount)).mul(accBonePerShare).div(MULTIPLIER);

        emit PositionMoved(_userAddrFrom, _userAddrTo, _amount);
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

        uint256 userBalance = totalBalanceOf(_userAddr);
        if (userBalance == 0) {
            return 0;
        }

        uint256 currentBonesBalance = boneToken.balanceOf(address(this));
        uint256 pendingBones = topDog.pendingBone(topDogPoolId, address(this)).mul(topDog.rewardMintPercent()).div(100);
        uint256 addedBones = currentBonesBalance.sub(lastKnownBonesBalance).add(pendingBones);
        uint256 accBonePerShareTemp = accBonePerShare.add(addedBones.mul(MULTIPLIER).div(lpDeposited));

        return userBalance.mul(accBonePerShareTemp).div(MULTIPLIER).sub(rewardDebts[_userAddr]);
    }

    /**
     * @notice Claim pending reward for user. User must manually claim reward from BoneLockers before call of this method
     * @notice Use claimRewardFromBoneLockers claim reward from BoneLockers
     */
    function claimReward(address _userAddr) public override nonReentrant updatePool {
        _claimRewardInternal(_userAddr);
    }

    function _claimRewardInternal(address _userAddr) internal {
        uint256 userBalance = totalBalanceOf(_userAddr);
        _sendPendingRewardInternal(_userAddr, userBalance);
        rewardDebts[_userAddr] = userBalance.mul(accBonePerShare).div(MULTIPLIER);
    }

    /**
     * @notice Calculates approximate share of user in claimable bones from BoneLockers for this pool.
     * @notice Not all this reward could be claimed at one call of `claimRewardFromBoneLockers` bcs of gas
     * @param _userAddr user address
     * @param _boneLockers array of bone lockers. Not expected that TopDog.boneLocker would be changes, but still
     */
    function getClaimableRewardAmountFromBoneLockers(address _userAddr, IBoneLocker[] memory _boneLockers) public view returns (uint256)
    {
        uint256 userBalance = totalBalanceOf(_userAddr);
        if (userBalance == 0) {
            return 0;
        }

        uint256 poolReward;
        for (uint256 i = 0; i < _boneLockers.length; ++i) {
            poolReward = poolReward.add(_boneLockers[i].getClaimableAmount(address(this)));
        }

        return poolReward.mul(userBalance).div(totalSupply());
    }

    /**
     * @notice Claim bones from BoneLockers FOR THIS POOL, not for user. User will get share from this amount
     * @notice Since it could be a lot of pending rewards items parameters are used limit tx size
     * @param _boneLockers array of bone lockers. Not expected that TopDog.boneLocker would be changes, but still
     * @param _maxBoneLockerRewardsAtOneClaim max amount of rewards items to claim from each BoneLocker, see getBoneLockerRewardsCount
     */
    function claimRewardFromBoneLockers(IBoneLocker[] memory _boneLockers, uint256 _maxBoneLockerRewardsAtOneClaim) public nonReentrant {
        for (uint256 i = 0; i < _boneLockers.length; ++i) {
            (uint256 left, uint256 right) = _boneLockers[i].getLeftRightCounters(address(this));
            if (right > left) {
                if (right - left > _maxBoneLockerRewardsAtOneClaim) {
                    right = left + _maxBoneLockerRewardsAtOneClaim;
                }
                _boneLockers[i].claimAll(right);
            }
        }
    }

    function getBoneLockerRewardsCount(IBoneLocker[] memory _boneLockers) public view returns (uint256[] memory rewards)
    {
        rewards = new uint256[](_boneLockers.length);

        for (uint256 locker_i = 0; locker_i < _boneLockers.length; ++locker_i) {
            IBoneLocker locker = _boneLockers[locker_i];
            (uint256 left, uint256 right) = locker.getLeftRightCounters(address(this));
            uint256 i;
            for (i = left; i < right; i++) {
                (, uint256 ts,) = locker.lockInfoByUser(address(this), i);
                if (block.timestamp < ts.add(locker.lockingPeriod())) {
                    break;
                }
            }

            rewards[locker_i] = i - left;
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

        // getting current reward (no separate methods)
        topDog.deposit(topDogPoolId, 0);

        uint256 currentBonesBalance = boneToken.balanceOf(address(this));
        uint256 addedBones = currentBonesBalance.sub(lastKnownBonesBalance);

        if (feePercent > 0 && feeReceiver != address(0)) {
            uint256 fee = addedBones.mul(feePercent).div(FEE_DENOMINATOR);
            TransferHelper.safeTransfer(address(boneToken), feeReceiver, fee);

            addedBones = addedBones.sub(fee);
            currentBonesBalance = currentBonesBalance.sub(fee);
        }

        lastKnownBonesBalance = currentBonesBalance;
        accBonePerShare = accBonePerShare.add(addedBones.mul(MULTIPLIER).div(lpDeposited));
    }

    function _sendPendingRewardInternal(address _userAddr, uint256 _userAmount) internal {
        if (_userAmount == 0) {
            return;
        }

        uint256 userBalance = totalBalanceOf(_userAddr);
        uint256 pending = userBalance.mul(accBonePerShare).div(MULTIPLIER).sub(rewardDebts[_userAddr]);
        if (pending == 0) {
            return;
        }

        _safeBoneTransfer(_userAddr, pending);
        lastKnownBonesBalance = boneToken.balanceOf(address(this));
    }

    /**
     * @dev Safe bone transfer function, just in case if rounding error causes pool to not have enough BONEs.
     */
    function _safeBoneTransfer(address _to, uint256 _amount) internal {
        uint256 boneBal = boneToken.balanceOf(address(this));
        if (_amount > boneBal) {
            TransferHelper.safeTransfer(address(boneToken), _to, boneBal);
        } else {
            TransferHelper.safeTransfer(address(boneToken), _to, _amount);
        }
    }

    /**
     * @dev Get sslp token for using in constructor
     */
    function getSsLpToken(ITopDog _topDog, uint256 _topDogPoolId) private view returns (address) {
        (IERC20 _sslpToken,,,) = _topDog.poolInfo(_topDogPoolId);

        return address(_sslpToken);
    }

    /**
     * @dev Get symbol of sslp token for using in constructor
     */
    function getSsLpTokenSymbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).symbol();
    }

    /**
     * @dev Get name of sslp token for using in constructor
     */
    function getSsLpTokenName(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).name();
    }

    /**
     * @dev Get token0 symbol of sslp token for using in constructor
     */
    function getSsLpTokenToken0Symbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getSsLpToken(_topDog, _topDogPoolId)).token0())).symbol();
    }

    /**
     * @dev Get token1 symbol of sslp token for using in constructor
     */
    function getSsLpTokenToken1Symbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getSsLpToken(_topDog, _topDogPoolId)).token1())).symbol();
    }

    function totalBalanceOf(address account) public view returns (uint256) {
        if (account == address(vault)) {
            return 0;
        }
        uint256 collateralsOnVault = vault.collaterals(address(this), account);
        return balanceOf(account).add(collateralsOnVault);
    }

    /**
     * @dev No direct transfers between users allowed since we store positions info in userInfo.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override onlyVault {
        super._transfer(sender, recipient, amount);
    }
}
