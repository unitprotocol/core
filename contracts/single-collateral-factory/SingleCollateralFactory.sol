// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IFactory.sol";
import "./interfaces/IStageDeployer.sol";

import "../USDP.sol";
import "../VaultParameters.sol";
import "../Vault.sol";

contract SingleCollateralFactory is Ownable, IFactory {

    string public constant override VERSION = '0.1.0';

    IStageDeployer public immutable usdpAndVaultDeployer;
    IStageDeployer public immutable registriesDeployer;
    IStageDeployer public immutable parametersDeployer;
    IStageDeployer public immutable managersDeployer;
    IStageDeployer public immutable oracleAndHelpersDeployer;

    mapping (uint => Deploy) deploys;
    uint public deploysCount;
    mapping (address => uint) public vaultDeploy;

    bool public deployOnlyForOwner = true;

    constructor(
        IStageDeployer usdpAndVaultDeployer_,
        IStageDeployer registriesDeployer_,
        IStageDeployer parametersDeployer_,
        IStageDeployer managersDeployer_,
        IStageDeployer oracleAndHelpersDeployer_
    ) {
        usdpAndVaultDeployer = usdpAndVaultDeployer_;
        usdpAndVaultDeployer_.setManager(address(this));

        registriesDeployer = registriesDeployer_;
        registriesDeployer_.setManager(address(this));

        parametersDeployer = parametersDeployer_;
        parametersDeployer_.setManager(address(this));

        managersDeployer = managersDeployer_;
        managersDeployer_.setManager(address(this));

        oracleAndHelpersDeployer = oracleAndHelpersDeployer_;
        oracleAndHelpersDeployer_.setManager(address(this));
    }

    function getDeploy(uint deployId_) public view returns (Deploy memory) {
        return deploys[deployId_];
    }

    function setDeployOnlyForOwner(bool value_) public onlyOwner {
        deployOnlyForOwner = value_;
    }

    function initDeploy(
        DeploySettings memory deploySettings_
    ) public {
        require(!deployOnlyForOwner || owner() == msg.sender, "FACTORY: UNAUTHORIZED");

        Deploy storage deploy = deploys[deploysCount];
        deploy.deploySettings = deploySettings_;

        emit DeployInitialized(deploysCount);

        deploysCount++;
    }

    function continueDeploy(uint deployId_) public {
        Deploy storage deploy = deploys[deployId_];
        require(deploy.deploySettings.collateral != address(0), "FACTORY: NOT_STARTED");
        require(!deploy.isFinished, "FACTORY: FINISHED");

        uint8 stage = deploy.stage;

        if (stage == 0) {
            address[] memory result = usdpAndVaultDeployer.deployStage(deploy);
            deploy.usdp = result[0];
            deploy.vaultParameters = result[1];
            deploy.vault = result[2];

            vaultDeploy[deploy.vault] = deployId_;

            deploy.stage = 1;
            emit StageDeployed(deployId_, 0);
            emit VaultDeployed(deployId_, deploy.vault);
        } else if (stage == 1) {
            address[] memory result = registriesDeployer.deployStage(deploy);
            deploy.collateralRegistry = result[0];
            deploy.cdpRegistry = result[1];
            deploy.oracleRegistry = result[2];

            deploy.stage = 2;
            emit StageDeployed(deployId_, 1);
        } else if (stage == 2) {
            address[] memory result = parametersDeployer.deployStage(deploy);
            deploy.vaultManagerParameters = result[0];
            deploy.vaultManagerBorrowFeeParameters = result[1];
            deploy.assetsBooleanParameters = result[2];

            deploy.stage = 3;
            emit StageDeployed(deployId_, 2);
        } else if (stage == 3) {
            address[] memory result = managersDeployer.deployStage(deploy);
            deploy.cdpManager = result[0];
            deploy.liquidationAuction = result[1];

            deploy.stage = 4;
            emit StageDeployed(deployId_, 3);
        } else if (stage == 4) {
            address[] memory result = oracleAndHelpersDeployer.deployStage(deploy);
            deploy.chainlinkOracle = result[0];
            deploy.assetParametersViewer = result[1];
            deploy.cdpViewer = result[2];

            deploy.stage = 5;
            emit StageDeployed(deployId_, 4);
        } else if (stage == 5) {
            usdpAndVaultDeployer.setUp(deploy);

            deploy.stage = 6;
            deploy.isFinished = true;
            emit DeployFinished(deployId_);
        } else {
            revert("FACTORY: BROKEN_LOGIC");
        }
    }
}