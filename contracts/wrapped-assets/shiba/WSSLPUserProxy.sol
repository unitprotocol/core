// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol"; // have to use OZ safemath since it is used in WSSLP

import "../../interfaces/wrapped-assets/ITopDog.sol";
import "../../helpers/TransferHelper.sol";


/**
 * @title WSSLPUserProxy
 **/
contract WSSLPUserProxy {
    using SafeMath for uint256;

    address public immutable manager;

    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;

    modifier onlyManager() {
        require(msg.sender == manager, "Unit Protocol Wrapped Assets: AUTH_FAILED");
        _;
    }

    constructor(ITopDog _topDog, uint256 _topDogPoolId) {
        manager = msg.sender;

        topDog = _topDog;
        topDogPoolId = _topDogPoolId;

        boneToken = _topDog.bone();
    }

    /**
     * @dev in case of change sslp
     */
    function approveSslpToTopDog(IERC20 _sslpToken) public onlyManager {
        TransferHelper.safeApprove(address(_sslpToken), address(topDog), type(uint256).max);
    }

    function deposit(uint256 _amount) public onlyManager {
        topDog.deposit(topDogPoolId, _amount);
    }

    function withdraw(IERC20 _sslpToken, uint256 _amount, address _sentTokensTo) public onlyManager {
        topDog.withdraw(topDogPoolId, _amount);
        TransferHelper.safeTransfer(address(_sslpToken), _sentTokensTo, _amount);
    }

    function pendingReward(address _feeReceiver, uint8 _feePercent) public view returns (uint) {
        uint balance = boneToken.balanceOf(address(this));
        uint pending = topDog.pendingBone(topDogPoolId, address(this)).mul(topDog.rewardMintPercent()).div(100);

        (uint amountWithoutFee, ) = _calcFee(balance.add(pending), _feeReceiver, _feePercent);
        return amountWithoutFee;
    }

    function claimReward(address _user, address _feeReceiver, uint8 _feePercent) public onlyManager {
        topDog.deposit(topDogPoolId, 0); // get current reward (no separate methods)

        _sendAllBonesToUser(_user, _feeReceiver, _feePercent);
    }

    function _calcFee(uint _amount, address _feeReceiver, uint8 _feePercent) internal pure returns (uint amountWithoutFee, uint fee) {
        if (_feePercent == 0 || _feeReceiver == address(0)) {
            return (_amount, 0);
        }

        fee = _amount.mul(_feePercent).div(100);
        return (_amount.sub(fee), fee);
    }

    function _sendAllBonesToUser(address _user, address _feeReceiver, uint8 _feePercent) internal {
        uint balance = boneToken.balanceOf(address(this));

        _sendBonesToUser(_user, balance, _feeReceiver, _feePercent);
    }

    function _sendBonesToUser(address _user, uint _amount, address _feeReceiver, uint8 _feePercent) internal {
        (uint amountWithoutFee, uint fee) = _calcFee(_amount, _feeReceiver, _feePercent);

        if (fee > 0) {
            TransferHelper.safeTransfer(address(boneToken), _feeReceiver, fee);
        }
        TransferHelper.safeTransfer(address(boneToken), _user, amountWithoutFee);
    }

    function getClaimableRewardFromBoneLocker(IBoneLocker _boneLocker, address _feeReceiver, uint8 _feePercent) public view returns (uint) {
        if (address(_boneLocker) == address(0)) {
            _boneLocker = topDog.boneLocker();
        }

        (uint amountWithoutFee, ) = _calcFee(_boneLocker.getClaimableAmount(address(this)), _feeReceiver, _feePercent);
        return amountWithoutFee;
    }

    function claimRewardFromBoneLocker(address _user, IBoneLocker _boneLocker, uint256 _maxBoneLockerRewardsAtOneClaim, address _feeReceiver, uint8 _feePercent) public onlyManager {
        if (address(_boneLocker) == address(0)) {
            _boneLocker = topDog.boneLocker();
        }

        (uint256 left, uint256 right) = _boneLocker.getLeftRightCounters(address(this));
        if (right <= left) {
            return;
        }

        if (_maxBoneLockerRewardsAtOneClaim > 0 && right - left > _maxBoneLockerRewardsAtOneClaim) {
            right = left + _maxBoneLockerRewardsAtOneClaim;
        }
        _boneLocker.claimAll(right);

        _sendAllBonesToUser(_user, _feeReceiver, _feePercent);
    }

    function emergencyWithdraw() public onlyManager {
        topDog.emergencyWithdraw(topDogPoolId);
    }

    function withdrawToken(address _token, address _user, uint _amount, address _feeReceiver, uint8 _feePercent) public onlyManager {
        if (_token == address(boneToken)) {
            _sendBonesToUser(_user, _amount, _feeReceiver, _feePercent);
        } else {
            TransferHelper.safeTransfer(_token, _user, _amount);
        }
    }

    function readBoneLocker(address _boneLocker, bytes calldata _callData) public view returns (bool success, bytes memory data) {
        (success, data) = _boneLocker.staticcall(_callData);
    }

    function callBoneLocker(address _boneLocker, bytes calldata _callData) public onlyManager returns (bool success, bytes memory data) {
        (success, data) = _boneLocker.call(_callData);
    }

    function getDepositedAmount() public view returns (uint amount) {
        (amount, ) = topDog.userInfo(topDogPoolId, address (this));
    }
}
