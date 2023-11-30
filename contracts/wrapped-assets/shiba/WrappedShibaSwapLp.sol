// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./WSSLPUserProxy.sol";
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
 * @dev Contract for wrapping ShibaSwap LP tokens.
 *      Inherits from IWrappedAsset, Auth2, ERC20, and ReentrancyGuard.
 **/
contract WrappedShibaSwapLp is IWrappedAsset, Auth2, ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    // Unique identifier for Unit Protocol Wrapped Asset
    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    // References to external contracts and immutable variables
    IVault public immutable vault;
    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;
    address public immutable userProxyImplementation;

    // User proxy mapping
    mapping(address => WSSLPUserProxy) public usersProxies;

    // Allowed selectors for bone lockers
    mapping (address => mapping (bytes4 => bool)) allowedBoneLockersSelectors;

    // Fee management variables
    address public feeReceiver;
    uint8 public feePercent = 10;

    /**
     * @dev Constructor for WrappedShibaSwapLp.
     * @param _vaultParameters Address of the vault parameters.
     * @param _topDog Address of the TopDog contract.
     * @param _topDogPoolId Pool ID for the TopDog contract.
     * @param _feeReceiver Address where fees are sent.
     */
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

        userProxyImplementation = address(new WSSLPUserProxy(_topDog, _topDogPoolId));
    }



    /**
     * @dev Sets the fee receiver address.
     * @param _feeReceiver The address to which fees should be sent.
     * @notice Only callable by the contract manager.
     * @emit FeeReceiverChanged Emits the new fee receiver address.
     */
    function setFeeReceiver(address _feeReceiver) public onlyManager {
        feeReceiver = _feeReceiver;

        emit FeeReceiverChanged(_feeReceiver);
    }

    /**
     * @dev Sets the fee percentage.
     * @param _feePercent The new fee percentage, cannot exceed 50%.
     * @notice Only callable by the contract manager.
     * @emit FeeChanged Emits the new fee percentage.
     */
    function setFee(uint8 _feePercent) public onlyManager {
        require(_feePercent <= 50, "Unit Protocol Wrapped Assets: INVALID_FEE");
        feePercent = _feePercent;

        emit FeeChanged(_feePercent);
    }

    /**
     * @dev Allows or disallows a selector on a bone locker.
     * @param _boneLocker Address of the bone locker.
     * @param _selector The function selector to allow or disallow.
     * @param _isAllowed Boolean value indicating whether the selector is allowed.
     * @notice Only callable by the contract manager.
     */
    function setAllowedBoneLockerSelector(address _boneLocker, bytes4 _selector, bool _isAllowed) public onlyManager {
        allowedBoneLockersSelectors[_boneLocker][_selector] = _isAllowed;
        if (_isAllowed) {
            emit AllowedBoneLockerSelectorAdded(_boneLocker, _selector);
        } else {
            emit AllowedBoneLockerSelectorRemoved(_boneLocker, _selector);
        }
    }

    /**
     * @dev Approves the SSLP token to be spent by the TopDog contract.
     * @notice Should be called in case of SSLP token change.
     * @notice Only callable by the user proxy.
     */
    function approveSslpToTopDog() public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        IERC20 sslpToken = getUnderlyingToken();
        userProxy.approveSslpToTopDog(sslpToken);
    }

    /**
     * @dev Allows deposit of SSLP tokens and issues wrapped tokens to the user.
     * @param _user Address of the user making the deposit.
     * @param _amount Amount of SSLP tokens to deposit.
     * @notice Only callable by the user or a CDPManager.
     * @notice Emits a Deposit event upon successful deposit.
     */
    function deposit(address _user, uint256 _amount) public override nonReentrant {
        require(_amount > 0, "Unit Protocol Wrapped Assets: INVALID_AMOUNT");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        IERC20 sslpToken = getUnderlyingToken();
        WSSLPUserProxy userProxy = _getOrCreateUserProxy(_user, sslpToken);

        // get tokens from user, need approve of sslp tokens to pool
        TransferHelper.safeTransferFrom(address(sslpToken), _user, address(userProxy), _amount);

        // deposit them to TopDog
        userProxy.deposit(_amount);

        // wrapped tokens to user
        _mint(_user, _amount);

        emit Deposit(_user, _amount);
    }

    /**
     * @dev Withdraws SSLP tokens from TopDog and unwraps the tokens.
     * @param _user Address of the user making the withdrawal.
     * @param _amount Amount of SSLP tokens to withdraw.
     * @notice Only callable by the user or a CDPManager.
     * @notice Emits a Withdraw event upon successful withdrawal.
     */
    function withdraw(address _user, uint256 _amount) public override nonReentrant {
        require(_amount > 0, "Unit Protocol Wrapped Assets: INVALID_AMOUNT");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        IERC20 sslpToken = getUnderlyingToken();
        WSSLPUserProxy userProxy = _requireUserProxy(_user);

        // get wrapped tokens from user
        _burn(_user, _amount);

        // withdraw funds from TopDog
        userProxy.withdraw(sslpToken, _amount, _user);

        emit Withdraw(_user, _amount);
    }

    /**
     * @dev Moves a position or its part to another user, typically used in liquidation scenarios.
     * @param _userFrom Address of the user from whom the position is moved.
     * @param _userTo Address of the user to whom the position is moved.
     * @param _amount Amount of the position to be moved.
     * @notice Only callable by the CDPManager.
     * @notice Emits PositionMoved event upon successful position transfer.
     */
    function movePosition(address _userFrom, address _userTo, uint256 _amount) public override nonReentrant hasVaultAccess {
        require(_userFrom != address(vault) && _userTo != address(vault), "Unit Protocol Wrapped Assets: NOT_ALLOWED_FOR_VAULT");
        if (_userFrom == _userTo || _amount == 0) {
            return;
        }

        IERC20 sslpToken = getUnderlyingToken();
        WSSLPUserProxy userFromProxy = _requireUserProxy(_userFrom);
        WSSLPUserProxy userToProxy = _getOrCreateUserProxy(_userTo, sslpToken);

        userFromProxy.withdraw(sslpToken, _amount, address(userToProxy));
        userToProxy.deposit(_amount);

        emit Withdraw(_userFrom, _amount);
        emit Deposit(_userTo, _amount);
        emit PositionMoved(_userFrom, _userTo, _amount);
    }

    /**
     * @dev Calculates the pending reward for a given user.
     * @param _user Address of the user for whom to calculate the reward.
     * @return uint256 Amount of the pending reward for the user.
     */
    function pendingReward(address _user) public override view returns (uint256) {
        WSSLPUserProxy userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            return 0;
        }

        return userProxy.pendingReward(feeReceiver, feePercent);
    }

    /**
     * @dev Claims the reward for a given user.
     * @param _user Address of the user claiming the reward.
     * @notice Only callable by the user.
     */
    function claimReward(address _user) public override nonReentrant {
        require(_user == msg.sender, "Unit Protocol Wrapped Assets: AUTH_FAILED");

        WSSLPUserProxy userProxy = _requireUserProxy(_user);
        userProxy.claimReward(_user, feeReceiver, feePercent);
    }

    /**
     * @dev Retrieves the claimable amount of reward from a specified BoneLocker.
     * @param _user Address of the user.
     * @param _boneLocker Address of the BoneLocker contract.
     * @return uint256 Claimable amount of reward from the BoneLocker.
     */
    function getClaimableRewardFromBoneLocker(address _user, IBoneLocker _boneLocker) public view returns (uint256) {
        WSSLPUserProxy userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            return 0;
        }

        return userProxy.getClaimableRewardFromBoneLocker(_boneLocker, feeReceiver, feePercent);
    }

    /**
     * @notice Claim bones from BoneLockers
     * @notice Since it could be a lot of pending rewards items parameters are used limit tx size
     * @param _boneLocker BoneLocker to claim, pass zero address to claim from current
     * @param _maxBoneLockerRewardsAtOneClaim max amount of rewards items to claim from BoneLocker, pass 0 to claim all rewards
     */
    function claimRewardFromBoneLocker(IBoneLocker _boneLocker, uint256 _maxBoneLockerRewardsAtOneClaim) public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        userProxy.claimRewardFromBoneLocker(msg.sender, _boneLocker, _maxBoneLockerRewardsAtOneClaim, feeReceiver, feePercent);
    }

    /**
     * @dev Retrieves the underlying SSLP token.
     * @return IERC20 Address of the underlying SSLP token.
     */
    function getUnderlyingToken() public override view returns (IERC20) {
        (IERC20 _sslpToken,,,) = topDog.poolInfo(topDogPoolId);

        return _sslpToken;
    }

    /**
     * @notice Withdraw tokens from topdog to user proxy without caring about rewards. EMERGENCY ONLY.
     * @notice To withdraw tokens from user proxy to user use `withdrawToken`
     */
    function emergencyWithdraw() public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);

        uint amount = userProxy.getDepositedAmount();
        _burn(msg.sender, amount);
        assert(balanceOf(msg.sender) == 0);

        userProxy.emergencyWithdraw();

        emit EmergencyWithdraw(msg.sender, amount);
    }

    /**
     * @dev Withdraws a specified token from the user proxy to the user.
     * @param _token Address of the token to withdraw.
     * @param _amount Amount of the token to withdraw.
     */
    function withdrawToken(address _token, uint _amount) public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        userProxy.withdrawToken(_token, msg.sender, _amount, feeReceiver, feePercent);

        emit TokenWithdraw(msg.sender, _token, _amount);
    }

    /**
     * @dev Reads data from a specified BoneLocker.
     * @param _user Address of the user.
     * @param _boneLocker Address of the BoneLocker.
     * @param _callData Calldata for the BoneLocker read.
     * @return (bool, bytes) Indicates if the operation was successful, and the returned data.
     */
    function readBoneLocker(address _user, address _boneLocker, bytes calldata _callData) public view returns (bool success, bytes memory data) {
        WSSLPUserProxy userProxy = _requireUserProxy(_user);
        (success, data) = userProxy.readBoneLocker(_boneLocker, _callData);
    }

    /**
     * @dev Calls a method on a specified BoneLocker.
     * @param _boneLocker Address of the BoneLocker.
     * @param _callData Calldata for the BoneLocker call.
     * @return (bool, bytes) Indicates if the operation was successful, and the returned data.
     */
    function callBoneLocker(address _boneLocker, bytes calldata _callData) public nonReentrant returns (bool success, bytes memory data) {
        bytes4 selector;
        assembly {
            selector := calldataload(_callData.offset)
        }
        require(allowedBoneLockersSelectors[_boneLocker][selector], "Unit Protocol Wrapped Assets: UNSUPPORTED_SELECTOR");

        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        (success, data) = userProxy.callBoneLocker(_boneLocker, _callData);
    }

    /**
     * @dev Retrieves the SSLP token address used in the constructor.
     * @param _topDog Reference to the TopDog contract.
     * @param _topDogPoolId Pool ID in the TopDog contract.
     * @return address Address of the SSLP token.
     */
    function getSsLpToken(ITopDog _topDog, uint256 _topDogPoolId) private view returns (address) {
        (IERC20 _sslpToken,,,) = _topDog.poolInfo(_topDogPoolId);

        return address(_sslpToken);
    }

    /**
     * @dev Retrieves the symbol of the SSLP token used in the constructor.
     * @param _topDog Reference to the TopDog contract.
     * @param _topDogPoolId Pool ID in the TopDog contract.
     * @return string The symbol of the SSLP token.
     */
    function getSsLpTokenSymbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).symbol();
    }

    /**
     * @dev Retrieves the name of the SSLP token used in the constructor.
     * @param _topDog Reference to the TopDog contract.
     * @param _topDogPoolId Pool ID in the TopDog contract.
     * @return string The name of the SSLP token.
     */
    function getSsLpTokenName(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(getSsLpToken(_topDog, _topDogPoolId)).name();
    }

    /**
     * @dev Retrieves the symbol of the token0 of the SSLP token used in the constructor.
     * @param _topDog Reference to the TopDog contract.
     * @param _topDogPoolId Pool ID in the TopDog contract.
     * @return string The symbol of the token0 of the SSLP token.
     */
    function getSsLpTokenToken0Symbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getSsLpToken(_topDog, _topDogPoolId)).token0())).symbol();
    }

    /**
     * @dev Retrieves the symbol of the token1 of the SSLP token used in the constructor.
     * @param _topDog Reference to the TopDog contract.
     * @param _topDogPoolId Pool ID in the TopDog contract.
     * @return string The symbol of the token1 of the SSLP token.
     */
    function getSsLpTokenToken1Symbol(ITopDog _topDog, uint256 _topDogPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getSsLpToken(_topDog, _topDogPoolId)).token1())).symbol();
    }

    /**
     * @dev Internal function to handle token transfers, restricting direct transfers between users.
     * @param sender Address sending the tokens.
     * @param recipient Address receiving the tokens.
     * @param amount Amount of tokens to transfer.
     * @notice Transfers are only allowed to and from the vault contract.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override onlyVault {
        require(sender == address(vault) || recipient == address(vault), "Unit Protocol Wrapped Assets: AUTH_FAILED");
        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Internal function to require the existence of a user proxy.
     * @param _user Address of the user to check.
     * @return WSSLPUserProxy Returns the user proxy.
     * @notice Reverts if the user proxy does not exist.
     */
    function _requireUserProxy(address _user) internal view returns (WSSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        require(address(userProxy) != address(0), "Unit Protocol Wrapped Assets: NO_DEPOSIT");
    }

    /**
     * @dev Internal function to get or create a user proxy.
     * @param _user Address of the user.
     * @param sslpToken SSLP token for which the proxy is created.
     * @return WSSLPUserProxy Returns the newly created or existing user proxy.
     */
    function _getOrCreateUserProxy(address _user, IERC20 sslpToken) internal returns (WSSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            // create new
            userProxy = WSSLPUserProxy(createClone(userProxyImplementation));
            userProxy.approveSslpToTopDog(sslpToken);

            usersProxies[_user] = userProxy;
        }
    }

    /**
     * @dev Internal function to create a clone of a target contract.
     * @dev see https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
     * @param target Address of the target contract to clone.
     * @return address Returns the address of the newly created clone.
     */
    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }

}
