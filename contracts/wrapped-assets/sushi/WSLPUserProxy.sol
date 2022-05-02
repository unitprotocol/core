// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol"; // have to use OZ safemath since it is used in WSLP

import "../../interfaces/wrapped-assets/sushi/IMasterChef.sol";
import "../../helpers/TransferHelper.sol";


/**
 * @title WSLPUserProxy
 **/
contract WSLPUserProxy {
    using SafeMath for uint256;

    address public immutable manager;

    IMasterChef public immutable rewardDistributor;
    uint256 public immutable rewardDistributorPoolId;
    IERC20 public immutable rewardToken;

    modifier onlyManager() {
        require(msg.sender == manager, "Unit Protocol Wrapped Assets: AUTH_FAILED");
        _;
    }

    constructor(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) {
        manager = msg.sender;

        rewardDistributor = _rewardDistributor;
        rewardDistributorPoolId = _rewardDistributorPoolId;

        rewardToken = _rewardDistributor.sushi();
    }

    /**
     * @dev in case of change lp
     */
    function approveLpToRewardDistributor(IERC20 _lpToken) public onlyManager {
        TransferHelper.safeApprove(address(_lpToken), address(rewardDistributor), type(uint256).max);
    }

    function deposit(uint256 _amount) public onlyManager {
        rewardDistributor.deposit(rewardDistributorPoolId, _amount);
    }

    function withdraw(IERC20 _lpToken, uint256 _amount, address _sentTokensTo) public onlyManager {
        rewardDistributor.withdraw(rewardDistributorPoolId, _amount);
        TransferHelper.safeTransfer(address(_lpToken), _sentTokensTo, _amount);
    }

    function pendingReward(address _feeReceiver, uint8 _feePercent) public view returns (uint) {
        uint balance = rewardToken.balanceOf(address(this));
        uint pending = rewardDistributor.pendingSushi(rewardDistributorPoolId, address(this));

        (uint amountWithoutFee, ) = _calcFee(balance.add(pending), _feeReceiver, _feePercent);
        return amountWithoutFee;
    }

    function claimReward(address _user, address _feeReceiver, uint8 _feePercent) public onlyManager {
        rewardDistributor.deposit(rewardDistributorPoolId, 0); // get current reward (no separate methods)

        _sendAllRewardTokensToUser(_user, _feeReceiver, _feePercent);
    }

    function _calcFee(uint _amount, address _feeReceiver, uint8 _feePercent) internal pure returns (uint amountWithoutFee, uint fee) {
        if (_feePercent == 0 || _feeReceiver == address(0)) {
            return (_amount, 0);
        }

        fee = _amount.mul(_feePercent).div(100);
        return (_amount.sub(fee), fee);
    }

    function _sendAllRewardTokensToUser(address _user, address _feeReceiver, uint8 _feePercent) internal {
        uint balance = rewardToken.balanceOf(address(this));

        _sendRewardTokensToUser(_user, balance, _feeReceiver, _feePercent);
    }

    function _sendRewardTokensToUser(address _user, uint _amount, address _feeReceiver, uint8 _feePercent) internal {
        (uint amountWithoutFee, uint fee) = _calcFee(_amount, _feeReceiver, _feePercent);

        if (fee > 0) {
            TransferHelper.safeTransfer(address(rewardToken), _feeReceiver, fee);
        }
        TransferHelper.safeTransfer(address(rewardToken), _user, amountWithoutFee);
    }

    function emergencyWithdraw() public onlyManager {
        rewardDistributor.emergencyWithdraw(rewardDistributorPoolId);
    }

    function withdrawToken(address _token, address _user, uint _amount, address _feeReceiver, uint8 _feePercent) public onlyManager {
        if (_token == address(rewardToken)) {
            _sendRewardTokensToUser(_user, _amount, _feeReceiver, _feePercent);
        } else {
            TransferHelper.safeTransfer(_token, _user, _amount);
        }
    }

    function getDepositedAmount() public view returns (uint amount) {
        (amount, ) = rewardDistributor.userInfo(rewardDistributorPoolId, address (this));
    }
}
