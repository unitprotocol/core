// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./WSLPUserProxy.sol";
import "../../helpers/ReentrancyGuard.sol";
import "../../helpers/TransferHelper.sol";
import "../../Auth2.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IERC20WithOptional.sol";
import "../../interfaces/wrapped-assets/IWrappedAsset.sol";
import "../../interfaces/wrapped-assets/sushi/IMasterChef.sol";
import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";

/**
 * @title WrappedSushiSwapLp
 **/
contract WrappedSushiSwapLp is IWrappedAsset, Auth2, ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    IVault public immutable vault;
    IMasterChef public immutable rewardDistributor;
    uint256 public immutable rewardDistributorPoolId;
    IERC20 public immutable rewardToken;

    address public immutable userProxyImplementation;
    mapping(address => WSLPUserProxy) public usersProxies;

    address public feeReceiver;
    uint8 public feePercent = 10;

    constructor(
        address _vaultParameters,
        IMasterChef _rewardDistributor,
        uint256 _rewardDistributorPoolId,
        address _feeReceiver
    )
    Auth2(_vaultParameters)
    ERC20(
        string(
            abi.encodePacked(
                "Wrapped by Unit ",
                getLpTokenName(_rewardDistributor, _rewardDistributorPoolId),
                " ",
                getLpTokenToken0Symbol(_rewardDistributor, _rewardDistributorPoolId),
                "-",
                getLpTokenToken1Symbol(_rewardDistributor, _rewardDistributorPoolId)
            )
        ),
        string(
            abi.encodePacked(
                "wu",
                getLpTokenSymbol(_rewardDistributor, _rewardDistributorPoolId),
                getLpTokenToken0Symbol(_rewardDistributor, _rewardDistributorPoolId),
                getLpTokenToken1Symbol(_rewardDistributor, _rewardDistributorPoolId)
            )
        )
    )
    {
        rewardToken = _rewardDistributor.sushi();
        rewardDistributor = _rewardDistributor;
        rewardDistributorPoolId = _rewardDistributorPoolId;
        vault = IVault(VaultParameters(_vaultParameters).vault());

        _setupDecimals(IERC20WithOptional(getLpToken(_rewardDistributor, _rewardDistributorPoolId)).decimals());

        feeReceiver = _feeReceiver;

        userProxyImplementation = address(new WSLPUserProxy(_rewardDistributor, _rewardDistributorPoolId));
    }

    function setFeeReceiver(address _feeReceiver) public onlyManager {
        feeReceiver = _feeReceiver;

        emit FeeReceiverChanged(_feeReceiver);
    }

    function setFee(uint8 _feePercent) public onlyManager {
        require(_feePercent <= 50, "Unit Protocol Wrapped Assets: INVALID_FEE");
        feePercent = _feePercent;

        emit FeeChanged(_feePercent);
    }

    /**
     * @notice Approve lp token to spend from user proxy (in case of change lp)
     */
    function approveLpToRewardDistributor() public nonReentrant {
        WSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        IERC20 lpToken = getUnderlyingToken();

        userProxy.approveLpToRewardDistributor(lpToken);
    }

    /**
     * @notice Get tokens from user, send them to the reward distributor, send to user wrapped tokens
     * @dev only user or CDPManager could call this method
     */
    function deposit(address _user, uint256 _amount) public override nonReentrant {
        require(_amount > 0, "Unit Protocol Wrapped Assets: INVALID_AMOUNT");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        IERC20 lpToken = getUnderlyingToken();
        WSLPUserProxy userProxy = _getOrCreateUserProxy(_user, lpToken);

        // get tokens from user, need approve of lp tokens to pool
        TransferHelper.safeTransferFrom(address(lpToken), _user, address(userProxy), _amount);

        // deposit them to the reward distributor
        userProxy.deposit(_amount);

        // wrapped tokens to user
        _mint(_user, _amount);

        emit Deposit(_user, _amount);
    }

    /**
     * @notice Unwrap tokens, withdraw from the reward distributor and send them to user
     * @dev only user or CDPManager could call this method
     */
    function withdraw(address _user, uint256 _amount) public override nonReentrant {
        require(_amount > 0, "Unit Protocol Wrapped Assets: INVALID_AMOUNT");
        require(msg.sender == _user || vaultParameters.canModifyVault(msg.sender), "Unit Protocol Wrapped Assets: AUTH_FAILED");

        IERC20 lpToken = getUnderlyingToken();
        WSLPUserProxy userProxy = _requireUserProxy(_user);

        // get wrapped tokens from user
        _burn(_user, _amount);

        // withdraw funds from the reward distributor
        userProxy.withdraw(lpToken, _amount, _user);

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

        IERC20 lpToken = getUnderlyingToken();
        WSLPUserProxy userFromProxy = _requireUserProxy(_userFrom);
        WSLPUserProxy userToProxy = _getOrCreateUserProxy(_userTo, lpToken);

        userFromProxy.withdraw(lpToken, _amount, address(userToProxy));
        userToProxy.deposit(_amount);

        emit Withdraw(_userFrom, _amount);
        emit Deposit(_userTo, _amount);
        emit PositionMoved(_userFrom, _userTo, _amount);
    }

    /**
     * @notice Calculates pending reward for user.
     */
    function pendingReward(address _user) public override view returns (uint256) {
        WSLPUserProxy userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            return 0;
        }

        return userProxy.pendingReward(feeReceiver, feePercent);
    }

    /**
     * @notice Claim pending direct reward for user.
     */
    function claimReward(address _user) public override nonReentrant {
        require(_user == msg.sender, "Unit Protocol Wrapped Assets: AUTH_FAILED");

        WSLPUserProxy userProxy = _requireUserProxy(_user);
        userProxy.claimReward(_user, feeReceiver, feePercent);
    }

    /**
     * @notice get LP token
     * @dev not immutable since it could be changed in the reward distributor
     */
    function getUnderlyingToken() public override view returns (IERC20) {
        (IERC20 _lpToken,,,) = rewardDistributor.poolInfo(rewardDistributorPoolId);

        return _lpToken;
    }

    /**
     * @notice Withdraw tokens from the reward distributor to user proxy without caring about rewards. EMERGENCY ONLY.
     * @notice To withdraw tokens from user proxy to user use `withdrawToken`
     */
    function emergencyWithdraw() public nonReentrant {
        WSLPUserProxy userProxy = _requireUserProxy(msg.sender);

        uint amount = userProxy.getDepositedAmount();
        _burn(msg.sender, amount);
        assert(balanceOf(msg.sender) == 0);

        userProxy.emergencyWithdraw();

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function withdrawToken(address _token, uint _amount) public nonReentrant {
        WSLPUserProxy userProxy = _requireUserProxy(msg.sender);
        userProxy.withdrawToken(_token, msg.sender, _amount, feeReceiver, feePercent);

        emit TokenWithdraw(msg.sender, _token, _amount);
    }

    /**
     * @dev Get lp token for using in constructor
     */
    function getLpToken(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) private view returns (address) {
        (IERC20 _lpToken,,,) = _rewardDistributor.poolInfo(_rewardDistributorPoolId);

        return address(_lpToken);
    }

    /**
     * @dev Get symbol of lp token for using in constructor
     */
    function getLpTokenSymbol(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) private view returns (string memory) {
        return IERC20WithOptional(getLpToken(_rewardDistributor, _rewardDistributorPoolId)).symbol();
    }

    /**
     * @dev Get name of lp token for using in constructor
     */
    function getLpTokenName(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) private view returns (string memory) {
        return IERC20WithOptional(getLpToken(_rewardDistributor, _rewardDistributorPoolId)).name();
    }

    /**
     * @dev Get token0 symbol of lp token for using in constructor
     */
    function getLpTokenToken0Symbol(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getLpToken(_rewardDistributor, _rewardDistributorPoolId)).token0())).symbol();
    }

    /**
     * @dev Get token1 symbol of lp token for using in constructor
     */
    function getLpTokenToken1Symbol(IMasterChef _rewardDistributor, uint256 _rewardDistributorPoolId) private view returns (string memory) {
        return IERC20WithOptional(address(ISushiSwapLpToken(getLpToken(_rewardDistributor, _rewardDistributorPoolId)).token1())).symbol();
    }

    /**
     * @dev No direct transfers between users allowed since we store positions info in userInfo.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override onlyVault {
        require(sender == address(vault) || recipient == address(vault), "Unit Protocol Wrapped Assets: AUTH_FAILED");
        super._transfer(sender, recipient, amount);
    }

    function _requireUserProxy(address _user) internal view returns (WSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        require(address(userProxy) != address(0), "Unit Protocol Wrapped Assets: NO_DEPOSIT");
    }

    function _getOrCreateUserProxy(address _user, IERC20 _lpToken) internal returns (WSLPUserProxy userProxy) {
        userProxy = usersProxies[_user];
        if (address(userProxy) == address(0)) {
            // create new
            userProxy = WSLPUserProxy(createClone(userProxyImplementation));
            userProxy.approveLpToRewardDistributor(_lpToken);

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
