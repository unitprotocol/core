// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "./AbstractDeployer.sol";
import "../interfaces/IWithNonce.sol";

import "../../USDP.sol";
import "../../VaultParameters.sol";
import "../../Vault.sol";

contract VaultDeployer is AbstractDeployer, IWithNonce {

    uint public override nonce;

    function deployStage(IFactory.Deploy memory deploy_) public override onlyManager returns (address[] memory result_) {
        require(
            deploy_.vaultParameters != address(0)
            && deploy_.usdp != address(0),
            "FACTORY: BROKEN_LOGIC"
        );

        Vault vault = new Vault(deploy_.vaultParameters, deploy_.usdp, address(0));

        nonce += 1;

        result_ = new address[](1);
        result_[0] = address(vault);
    }
}