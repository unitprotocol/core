// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // 'contracts' are used intentionally, since there is no dependencies in this interface
import "@openzeppelin/contracts/proxy/Clones.sol"; // 'contracts' are used intentionally, since there is no dependencies in this library
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./WSLPUserProxy.sol";
import "../../helpers/ReentrancyGuard.sol";
import "../../helpers/TransferHelper.sol";
import "../../Auth2.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IERC20WithOptional.sol";
import "../../interfaces/wrapped-assets/IWrappedAssetUpgradeable.sol";
import "../../interfaces/wrapped-assets/sushi/IMasterChef.sol";
import "../../interfaces/wrapped-assets/ISushiSwapLpToken.sol";
import "../../interfaces/IVaultParameters.sol";

/**
 * @title WrappedSushiSwapLp
 **/
contract WrappedSushiSwapLp is IWrappedAssetUpgradeable, Auth2, ERC20Upgradeable, ReentrancyGuard {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant override isUnitProtocolWrappedAsset = keccak256("UnitProtocolWrappedAsset");

    IVault public immutable vault;
    IMasterChef public immutable rewardDistributor;
    IERC20 public immutable rewardToken;

    address public immutable userProxyImplementation;

    uint256 public rewardDistributorPoolId;
    mapping(address => WSLPUserProxy) public usersProxies;

    constructor(
        IVaultParameters _vaultParameters,
        IMasterChef _rewardDistributor,
        IERC20 _rewardToken,
        address _userProxyImplementation
    )
        Auth2(address(_vaultParameters))
    {
        vault = IVault(_vaultParameters.vault());
        rewardDistributor = _rewardDistributor;
        rewardToken = _rewardToken;

        userProxyImplementation = _userProxyImplementation;
    }

    function initialize(uint256 _rewardDistributorPoolId) initializer public {
        require(rewardDistributorPoolId < type(uint96).max, "Unit Protocol Wrapped Assets: TOO_MANY_POOLS"); // in user proxies pool id is stores in uint96
        rewardDistributorPoolId = _rewardDistributorPoolId;

        (IERC20 lpToken,,,) = rewardDistributor.poolInfo(_rewardDistributorPoolId);
        address lpTokenAddr = address(lpToken);
        string memory lpToken0Symbol = IERC20WithOptional(address(ISushiSwapLpToken(lpTokenAddr).token0())).symbol();
        string memory lpToken1Symbol = IERC20WithOptional(address(ISushiSwapLpToken(lpTokenAddr).token1())).symbol();

        __ERC20_init(
            string(
                abi.encodePacked(
                    "Wrapped by Unit ",
                    IERC20WithOptional(lpTokenAddr).name(),
                    " ",
                    lpToken0Symbol,
                    "-",
                    lpToken1Symbol
                )
            ),
            string(
                abi.encodePacked(
                    "wu",
                    IERC20WithOptional(lpTokenAddr).symbol(),
                    lpToken0Symbol,
                    lpToken1Symbol
                )
            )
        );

        _setupDecimals(IERC20WithOptional(lpTokenAddr).decimals());
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

        return userProxy.pendingReward();
    }

    /**
     * @notice Claim pending direct reward for user.
     */
    function claimReward(address _user) public override nonReentrant {
        require(_user == msg.sender, "Unit Protocol Wrapped Assets: AUTH_FAILED");

        WSLPUserProxy userProxy = _requireUserProxy(_user);
        userProxy.claimReward(_user);
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
        userProxy.withdrawToken(_token, msg.sender, _amount);

        emit TokenWithdraw(msg.sender, _token, _amount);
    }

    /**
     * @dev No direct transfers between users allowed since we store positions info in userInfo.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(msg.sender == address(vault), "Unit Protocol: AUTH_FAILED"); // do not use onlyVault to save some gas by avoiding external call
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
            userProxy = WSLPUserProxy(Clones.clone(userProxyImplementation));
            userProxy.initialize(uint96(rewardDistributorPoolId), _lpToken); // overflow is checked in initialize

            usersProxies[_user] = userProxy;
        }
    }
}
