// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "../../interfaces/wrapped-assets/sushi/IWSLPFactory.sol";
import "../../interfaces/wrapped-assets/sushi/IMasterChef.sol";
import "../../interfaces/IVault.sol";
import "../../interfaces/IVaultParameters.sol";
import "./WSLPUserProxy.sol";
import "./WrappedSushiSwapLp.sol";


/**
 * @title WSLPFactory
 **/
contract WSLPFactory is IWSLPFactory, Auth2 {

    // these variables stored just for info
    IMasterChef public immutable rewardDistributor;
    IERC20 public immutable rewardToken;

    address public immutable wrappedSushiSwapLpImplementation;
    address public immutable userProxyImplementation;

    FeeInfo public override feeInfo;

    mapping(uint => address) public wrappedLpByPoolId;

    constructor(
        IVaultParameters _vaultParameters,
        IMasterChef _rewardDistributor,
        address _feeReceiver,
        uint8 _feePercent
    )
        Auth2(address(_vaultParameters))
    {
        IERC20 rewardTokenInternal = _rewardDistributor.sushi();
        rewardToken = rewardTokenInternal;

        rewardDistributor = _rewardDistributor;

        feeInfo = FeeInfo(_feeReceiver, _feePercent);

        address userProxyImplementationInternal = address(new WSLPUserProxy(this, _rewardDistributor));
        userProxyImplementation = userProxyImplementationInternal;

        WrappedSushiSwapLp wrappedSushiSwapLpImplementationInternal = new WrappedSushiSwapLp(
            _vaultParameters, _rewardDistributor, rewardTokenInternal, userProxyImplementationInternal
        );
        wrappedSushiSwapLpImplementation = address(wrappedSushiSwapLpImplementationInternal);


        // initialize implementations just not to allow to do it by somebody else
        (IERC20 lpToken,,,) = _rewardDistributor.poolInfo(0);
        WSLPUserProxy(userProxyImplementationInternal).initialize(0, lpToken);

        wrappedSushiSwapLpImplementationInternal.initialize(0);

    }

    function setFee(address _feeReceiver, uint8 _feePercent) public override onlyManager {
        require(_feePercent <= 50, "Unit Protocol Wrapped Assets: INVALID_FEE");
        feeInfo = FeeInfo(_feeReceiver, _feePercent);

        emit FeeChanged(_feeReceiver, _feePercent);
    }

    function deploy(uint256 _rewardDistributorPoolId) public override onlyManager returns (address wrappedLp) {
        require(wrappedLpByPoolId[_rewardDistributorPoolId] == address(0), "Unit Protocol Wrapped Assets: ALREADY_DEPLOYED");

        wrappedLp = Clones.clone(wrappedSushiSwapLpImplementation);
        WrappedSushiSwapLp(wrappedLp).initialize(_rewardDistributorPoolId);

        wrappedLpByPoolId[_rewardDistributorPoolId] = wrappedLp;
        emit WrappedLpDeployed(wrappedLp, _rewardDistributorPoolId);
    }
}
