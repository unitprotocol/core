// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol"; // have to use OZ safemath since it is used in WSLP

import "../../interfaces/wrapped-assets/sushi/IMasterChef.sol";
import "../../interfaces/wrapped-assets/sushi/IWSLPFactory.sol";
import "../../helpers/TransferHelper.sol";

/**
 * @title WSLPUserProxy
 **/
contract WSLPUserProxy {
    using SafeMath for uint256;

    IWSLPFactory immutable factory;

    IMasterChef public immutable rewardDistributor;
    IERC20 public immutable rewardToken;

    // to store in one slot rewardDistributorPoolId was reduced to uint96. 7*10^28 pools are quite enough
    address public manager;
    uint96 public rewardDistributorPoolId;

    modifier onlyManager() {
        require(msg.sender == manager, "Unit Protocol Wrapped Assets: AUTH_FAILED");
        _;
    }

    constructor(IWSLPFactory _factory, IMasterChef _rewardDistributor) {
        factory = _factory;
        rewardDistributor = _rewardDistributor;

        rewardToken = _rewardDistributor.sushi();
    }

    function initialize(uint96 _rewardDistributorPoolId, IERC20 _lpToken) public {
        require(manager == address(0), "Unit Protocol Wrapped Assets: ALREADY_INITIALIZED");

        manager = msg.sender;
        rewardDistributorPoolId = _rewardDistributorPoolId;

        TransferHelper.safeApprove(address(_lpToken), address(rewardDistributor), type(uint256).max);
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

    function pendingReward() public view returns (uint) {
        uint balance = rewardToken.balanceOf(address(this));
        uint pending = rewardDistributor.pendingSushi(rewardDistributorPoolId, address(this));

        (uint amountWithoutFee,,) = _calcFee(balance.add(pending));
        return amountWithoutFee;
    }

    function claimReward(address _user) public onlyManager {
        rewardDistributor.deposit(rewardDistributorPoolId, 0); // get current reward (no separate methods)

        _sendAllRewardTokensToUser(_user);
    }

    function _calcFee(uint _amount) internal view returns (uint amountWithoutFee, uint fee, address feeReceiver) {
        (address _feeReceiver, uint8 _feePercent) = factory.feeInfo();
        if (_feePercent == 0 || _feeReceiver == address(0)) {
            return (_amount, 0, address(0));
        }

        fee = _amount.mul(_feePercent).div(100);
        return (_amount.sub(fee), fee, _feeReceiver);
    }

    function _sendAllRewardTokensToUser(address _user) internal {
        uint balance = rewardToken.balanceOf(address(this));

        _sendRewardTokensToUser(_user, balance);
    }

    function _sendRewardTokensToUser(address _user, uint _amount) internal {
        (uint amountWithoutFee, uint fee, address feeReceiver) = _calcFee(_amount);

        if (fee > 0) {
            TransferHelper.safeTransfer(address(rewardToken), feeReceiver, fee);
        }
        TransferHelper.safeTransfer(address(rewardToken), _user, amountWithoutFee);
    }

    function emergencyWithdraw() public onlyManager {
        rewardDistributor.emergencyWithdraw(rewardDistributorPoolId);
    }

    function withdrawToken(address _token, address _user, uint _amount) public onlyManager {
        if (_token == address(rewardToken)) {
            _sendRewardTokensToUser(_user, _amount);
        } else {
            TransferHelper.safeTransfer(_token, _user, _amount);
        }
    }

    function getDepositedAmount() public view returns (uint amount) {
        (amount, ) = rewardDistributor.userInfo(rewardDistributorPoolId, address (this));
    }
}
