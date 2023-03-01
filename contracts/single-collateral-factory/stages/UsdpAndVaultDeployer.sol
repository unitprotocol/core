// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";
import "../lib/RLPEncode.sol";
import "../interfaces/IStageDeployerWithNonce.sol";

import "../../interfaces/vault-managers/parameters/IVaultManagerParameters.sol";
import "../../interfaces/ICollateralRegistry.sol";
import "../../interfaces/IOracleRegistry.sol";

import "../../USDP.sol";
import "../../VaultParameters.sol";
import "../../Vault.sol";


contract UsdpAndVaultDeployer is AbstractDeployer, IWithNonce {

    uint public constant CHAINLINK_ORACLE = 5;

    /**
     * @dev we need to deploy these 3 contracts at once, but if do it in one deployer it reaches contract size limit
     */
    IStageDeployerWithNonce public immutable vaultDeployer;

    uint public override nonce;

    constructor(IStageDeployerWithNonce vaultDeployer_) {
        vaultDeployer = vaultDeployer_;
        vaultDeployer_.setManager(address(this));
    }

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {

        address calculatedVaultParameters = calcAddress(address(this), nonce + 2);
        address calculatedVault = calcAddress(address(vaultDeployer), vaultDeployer.nonce() + 1);

        USDP usdp = new USDP(calculatedVaultParameters, deploy_.deploySettings.stableName, deploy_.deploySettings.stableSymbol);

        VaultParameters vaultParameters = new VaultParameters(payable(calculatedVault), deploy_.deploySettings.commonFeeCollector);
        require(calculatedVaultParameters == address(vaultParameters), "FACTORY: BROKEN_NONCE1");

        deploy_.vaultParameters = address(vaultParameters); // just to send to vaultDeployer
        deploy_.usdp = address(usdp);
        address[] memory vaultDeployResult = vaultDeployer.deployStage(deploy_);
        require(calculatedVault == vaultDeployResult[0], "FACTORY: BROKEN_NONCE2");

        nonce += 2;

        result_ = new address[](3);
        result_[0] = address(usdp);
        result_[1] = address(vaultParameters);
        result_[2] = address(vaultDeployResult[0]);
    }

    function setUp(IFactory.Deploy memory deploy_) public override onlyManager {
        require(
            deploy_.oracleRegistry != address(0)
            && deploy_.chainlinkOracle != address(0)
            && deploy_.vaultParameters != address(0)
            && deploy_.vaultManagerParameters != address(0)
            && deploy_.collateralRegistry != address(0)
            && deploy_.cdpManager != address(0)
            && deploy_.liquidationAuction != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        USDP usdp = USDP(deploy_.usdp);
        usdp.setMinter(deploy_.vault, true);

        IOracleRegistry oracleRegistry = IOracleRegistry(deploy_.oracleRegistry);
        oracleRegistry.setOracle(CHAINLINK_ORACLE, deploy_.chainlinkOracle);
        oracleRegistry.setOracleTypeForAsset(deploy_.deploySettings.collateral, CHAINLINK_ORACLE);

        VaultParameters vaultParameters = VaultParameters(deploy_.vaultParameters);
        vaultParameters.setManager(deploy_.vaultManagerParameters, true);
        vaultParameters.setVaultAccess(deploy_.cdpManager, true);
        vaultParameters.setVaultAccess(deploy_.liquidationAuction, true);

        IVaultManagerParameters vaultManagerParameters = IVaultManagerParameters(deploy_.vaultManagerParameters);
        uint[] memory oracles = new uint[](1);
        oracles[0] = CHAINLINK_ORACLE;
        vaultManagerParameters.setCollateral(
            deploy_.deploySettings.collateral,
            deploy_.deploySettings.stabilityFeePercent3Decimals,
            deploy_.deploySettings.liquidationFeePercent,
            deploy_.deploySettings.initialCollateralRatioPercent,
            deploy_.deploySettings.liquidationRatioPercent,
            deploy_.deploySettings.liquidationDiscountPercent3Decimals,
            deploy_.deploySettings.devaluationPeriodSeconds,
            type(uint).max,
            oracles
        );

        ICollateralRegistry collateralRegistry = ICollateralRegistry(deploy_.collateralRegistry);
        collateralRegistry.addCollateral(deploy_.deploySettings.collateral);

        vaultParameters.setManager(address(this), false);
    }

    function calcAddress(address caller_, uint nonce_) internal pure returns (address) {
        bytes[] memory list = new bytes[](2);

        list[0] = RLPEncode.encodeAddress(caller_);
        list[1] = RLPEncode.encodeUint(nonce_);

        return address(uint160(uint256(keccak256(RLPEncode.encodeList(list)))));
    }
}
