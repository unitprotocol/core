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
 * @dev Proxy contract for managing Wrapped Sushiswap Liquidity Pool (WSSLP) interactions.
 */
contract WSSLPUserProxy {
    using SafeMath for uint256;

    address public immutable manager;
    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;

    /**
     * @dev Ensures that only the manager can call the function.
     */
    modifier onlyManager() {
        require(msg.sender == manager, "Unit Protocol Wrapped Assets: AUTH_FAILED");
        _;
    }

    /**
     * @dev Sets the manager to the creator of the contract, and initializes contract state.
     * @param _topDog Address of the TopDog contract.
     * @param _topDogPoolId Pool ID for the TopDog contract.
     */
    constructor(ITopDog _topDog, uint256 _topDogPoolId) {
        manager = msg.sender;

        topDog = _topDog;
        topDogPoolId = _topDogPoolId;

        boneToken = _topDog.bone();
    }

    /**
     * @dev Approves the specified amount of SSLP tokens to be managed by the TopDog contract.
     *      This is necessary in case of a change in SSLP.
     * @param _sslpToken Address of the SSLP token to be approved.
     */
    function approveSslpToTopDog(IERC20 _sslpToken) public onlyManager {
        TransferHelper.safeApprove(address(_sslpToken), address(topDog), type(uint256).max);
    }

    /**
     * @dev Deposits the specified amount of SSLP tokens into the TopDog pool.
     * @param _amount Amount of SSLP tokens to deposit.
     */
    function deposit(uint256 _amount) public onlyManager {
        topDog.deposit(topDogPoolId, _amount);
    }

    /**
     * @dev Withdraws the specified amount of SSLP tokens from the TopDog pool.
     * @param _sslpToken Address of the SSLP token to withdraw.
     * @param _amount Amount of SSLP tokens to withdraw.
     * @param _sentTokensTo Address to send the withdrawn tokens to.
     */
    function withdraw(IERC20 _sslpToken, uint256 _amount, address _sentTokensTo) public onlyManager {
        topDog.withdraw(topDogPoolId, _amount);
        TransferHelper.safeTransfer(address(_sslpToken), _sentTokensTo, _amount);
    }

    /**
     * @dev Calculates the pending reward, accounting for fees.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the reward that will be taken as a fee.
     * @return amountWithoutFee Amount of reward after fee deduction.
     */
    function pendingReward(address _feeReceiver, uint8 _feePercent) public view returns (uint) {
        uint balance = boneToken.balanceOf(address(this));
        uint pending = topDog.pendingBone(topDogPoolId, address(this)).mul(topDog.rewardMintPercent()).div(100);

        (uint amountWithoutFee, ) = _calcFee(balance.add(pending), _feeReceiver, _feePercent);
        return amountWithoutFee;
    }

    /**
     * @dev Claims the reward, accounting for fees, and sends it to the user.
     * @param _user Address to send the reward to.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the reward that will be taken as a fee.
     */
    function claimReward(address _user, address _feeReceiver, uint8 _feePercent) public onlyManager {
        topDog.deposit(topDogPoolId, 0); // get current reward (no separate methods)

        _sendAllBonesToUser(_user, _feeReceiver, _feePercent);
    }

    /**
     * @dev Internal function to calculate the fee and amount after fee deduction.
     * @param _amount Amount to calculate the fee on.
     * @param _feeReceiver Address to send the fee to. If this is address(0), no fee is applied.
     * @param _feePercent Percentage of the amount that will be taken as a fee.
     * @return amountWithoutFee Amount after fee deduction.
     * @return fee Calculated fee amount.
     */
    function _calcFee(uint _amount, address _feeReceiver, uint8 _feePercent) internal pure returns (uint amountWithoutFee, uint fee) {
        if (_feePercent == 0 || _feeReceiver == address(0)) {
            return (_amount, 0);
        }

        fee = _amount.mul(_feePercent).div(100);
        return (_amount.sub(fee), fee);
    }

    /**
     * @dev Internal function for sending all BONE tokens to the specified user, accounting for fees.
     * @param _user Address to send the BONE tokens to.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the reward that will be taken as a fee.
     */
    function _sendAllBonesToUser(address _user, address _feeReceiver, uint8 _feePercent) internal {
        uint balance = boneToken.balanceOf(address(this));

        _sendBonesToUser(_user, balance, _feeReceiver, _feePercent);
    }

    /**
     * @dev Internal function for sending specified amount of BONE tokens to the user, accounting for fees.
     * @param _user Address to send the BONE tokens to.
     * @param _amount Amount of BONE tokens to send.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the amount that will be taken as a fee.
     */
    function _sendBonesToUser(address _user, uint _amount, address _feeReceiver, uint8 _feePercent) internal {
        (uint amountWithoutFee, uint fee) = _calcFee(_amount, _feeReceiver, _feePercent);

        if (fee > 0) {
            TransferHelper.safeTransfer(address(boneToken), _feeReceiver, fee);
        }
        TransferHelper.safeTransfer(address(boneToken), _user, amountWithoutFee);
    }

    /**
     * @dev Calculates claimable reward from BoneLocker, accounting for fees.
     * @param _boneLocker Address of the BoneLocker contract.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the reward that will be taken as a fee.
     * @return amountWithoutFee Amount of reward after fee deduction.
     */
    function getClaimableRewardFromBoneLocker(IBoneLocker _boneLocker, address _feeReceiver, uint8 _feePercent) public view returns (uint) {
        if (address(_boneLocker) == address(0)) {
            _boneLocker = topDog.boneLocker();
        }

        (uint amountWithoutFee, ) = _calcFee(_boneLocker.getClaimableAmount(address(this)), _feeReceiver, _feePercent);
        return amountWithoutFee;
    }

    /**
     * @dev Claims rewards from the BoneLocker contract, subject to a maximum limit per claim, and accounts for fees.
     * @param _user Address to send the claimed BONE tokens to.
     * @param _boneLocker Address of the BoneLocker contract.
     * @param _maxBoneLockerRewardsAtOneClaim Maximum amount of rewards that can be claimed in one transaction.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the reward that will be taken as a fee.
     */
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


    /**
     * @dev Emergency function for withdrawing all deposits from the TopDog pool.
     */
    function emergencyWithdraw() public onlyManager {
        topDog.emergencyWithdraw(topDogPoolId);
    }

    /**
     * @dev Withdraws a specified token from the contract, accounting for fees.
     * @param _token Address of the token to withdraw.
     * @param _user Address to send the withdrawn tokens to.
     * @param _amount Amount of tokens to withdraw.
     * @param _feeReceiver Address to send the fee to.
     * @param _feePercent Percentage of the withdrawal amount that will be taken as a fee.
     */
    function withdrawToken(address _token, address _user, uint _amount, address _feeReceiver, uint8 _feePercent) public onlyManager {
        if (_token == address(boneToken)) {
            _sendBonesToUser(_user, _amount, _feeReceiver, _feePercent);
        } else {
            TransferHelper.safeTransfer(_token, _user, _amount);
        }
    }

    /**
     * @dev Reads data from the BoneLocker contract without altering state.
     * @param _boneLocker Address of the BoneLocker contract.
     * @param _callData Calldata to be sent to the BoneLocker contract.
     * @return success Boolean indicating if the call was successful.
     * @return data Data returned from the BoneLocker contract.
     */
    function readBoneLocker(address _boneLocker, bytes calldata _callData) public view returns (bool success, bytes memory data) {
        (success, data) = _boneLocker.staticcall(_callData);
    }

    /**
     * @dev Calls a function on the BoneLocker contract.
     * @param _boneLocker Address of the BoneLocker contract.
     * @param _callData Calldata to be sent to the BoneLocker contract.
     * @return success Boolean indicating if the call was successful.
     * @return data Data returned from the BoneLocker contract.
     */
    function callBoneLocker(address _boneLocker, bytes calldata _callData) public onlyManager returns (bool success, bytes memory data) {
        (success, data) = _boneLocker.call(_callData);
    }

    /**
     * @dev Returns the amount of tokens deposited by this contract in the TopDog pool.
     * @return amount Amount of tokens deposited in the TopDog pool.
     */
    function getDepositedAmount() public view returns (uint amount) {
        (amount, ) = topDog.userInfo(topDogPoolId, address(this));
    }
}
