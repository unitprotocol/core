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
 **/
contract WrappedShibaSwapLp is IWrappedAsset, Auth2, ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant MULTIPLIER = 1e12;

    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    IVault public immutable vault;
    ITopDog public immutable topDog;
    uint256 public immutable topDogPoolId;
    IERC20 public immutable boneToken;

    address public immutable userProxyImplementation;
    mapping(address => WSSLPUserProxy) public usersProxies;

    uint256 public feePercent = 10;
    uint256 public constant FEE_DENOMINATOR = 100;
    address public feeReceiver;

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
     * @notice Approve sslp token to spend from user proxy (in case of change sslp)
     */
    function approveSslpToTopDog() public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        IERC20 sslpToken = getUnderlyingToken();

        userProxy.approveSslpToTopDog(sslpToken);
    }

    /**
     * @notice Get tokens from user, send them to TopDog, sent to user wrapped tokens
     * @dev only user or CDPManager could call this method
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
     * @notice Unwrap tokens, withdraw from TopDog and send them to user
     * @dev only user or CDPManager could call this method
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
     * @notice Manually move position (or its part) to another user (for example in case of liquidation)
     * @dev Important! Use only with additional token transferring outside this function (example: liquidation - tokens are in vault and transferred by vault)
     * @dev only CDPManager could call this method
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
     * @notice Calculates pending reward for user. Not taken into account unclaimed reward from BoneLockers.
     * @notice Use getClaimableRewardFromBoneLocker to calculate unclaimed reward from BoneLockers
     */
    function pendingReward(address _user) public override view returns (uint256) {
        WSSLPUserProxy userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            return 0;
        }

        return userProxy.pendingReward(feeReceiver, feePercent);
    }

    /**
     * @notice Claim pending direct reward for user.
     * @notice Use claimRewardFromBoneLockers claim reward from BoneLockers
     */
    function claimReward(address _user) public override nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(_user);

        userProxy.claimReward(feeReceiver, feePercent);
    }

    /**
     * @notice Get claimable amount from BoneLocker
     * @param _user user address
     * @param _boneLocker BoneLocker to check, pass zero address to check current
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
    function claimRewardFromBoneLocker(address _user, IBoneLocker _boneLocker, uint256 _maxBoneLockerRewardsAtOneClaim) public nonReentrant {
        WSSLPUserProxy userProxy = _requireUserProxy(_user);

        userProxy.claimRewardFromBoneLocker(_boneLocker, _maxBoneLockerRewardsAtOneClaim, feeReceiver, feePercent);
    }

    /**
     * @notice get SSLP token
     * @dev not immutable since it could be changed in TopDog
     */
    function getUnderlyingToken() public override view returns (IERC20) {
        (IERC20 _sslpToken,,,) = topDog.poolInfo(topDogPoolId);

        return _sslpToken;
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

    /**
     * @dev No direct transfers between users allowed since we store positions info in userInfo.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override onlyVault {
        super._transfer(sender, recipient, amount);
    }

    function _requireUserProxy(address _user) internal view returns (WSSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        require(address(userProxy) != address(0), "Unit Protocol Wrapped Assets: NO_DEPOSIT");
    }

    function _getOrCreateUserProxy(address _user, IERC20 sslpToken) internal returns (WSSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            // create new
            userProxy = WSSLPUserProxy(createClone(userProxyImplementation));
            userProxy.init(_user, sslpToken);

            usersProxies[_user] = userProxy;
        }
    }

    /**
     * @dev see https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
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
