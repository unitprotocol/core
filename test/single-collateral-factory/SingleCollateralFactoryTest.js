const {expect} = require("chai");
const {ethers} = require("hardhat");
const {deployContract, attachContract} = require("../helpers/ethersUtils");

const ZERO = '0x0000000000000000000000000000000000000000';
const COMMON_FEE_COLLECTOR = '0x0000000000000000000000000000000000000001';
const ISSUANCE_FEE_COLLECTOR = '0x0000000000000000000000000000000000000002';
const COLLATERAL = '0x0000000000000000000000000000000000000003';
const CHAINLINK_AGGREGATOR = '0x0000000000000000000000000000000000000004';

BN = ethers.BigNumber.from
const ether = ethers.utils.parseUnits;


describe(`SingleCollateralFactoryTest`, function () {

    beforeEach(async function () {
        context = this;

        [this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();

        this.vaultDeployer = await deployContract('VaultDeployer');
        this.usdpVaultDeployer = await deployContract('UsdpAndVaultDeployer', this.vaultDeployer.address);
        this.registriesDeployer = await deployContract('RegistriesDeployer');
        this.parametersDeployer = await deployContract('ParametersDeployer');
        this.managersDeployer = await deployContract('ManagersDeployer');
        this.oracleAndHelpersDeployer = await deployContract('OracleAndHelpersDeployer');
        this.factory = await deployContract(
            'SingleCollateralFactory',
            this.usdpVaultDeployer.address,
            this.registriesDeployer.address,
            this.parametersDeployer.address,
            this.managersDeployer.address,
            this.oracleAndHelpersDeployer.address
        );
    });

    it("check deploy and print gas ", async function () {
        console.log("VaultDeployer data:", this.vaultDeployer.deployTransaction.data.length / 2)
        console.log("UsdpAndVaultDeployer data:", this.usdpVaultDeployer.deployTransaction.data.length / 2)
        console.log("RegistriesDeployer data:", this.registriesDeployer.deployTransaction.data.length / 2)
        console.log("ParametersDeployer data:", this.parametersDeployer.deployTransaction.data.length / 2)
        console.log("ManagersDeployer data:", this.managersDeployer.deployTransaction.data.length / 2)
        console.log("OracleAndHelpersDeployer data:", this.oracleAndHelpersDeployer.deployTransaction.data.length / 2)
        console.log("SingleCollateralFactory data:", this.factory.deployTransaction.data.length / 2)

        const deployParameters = {
            stableName: "USDP-WETH stablecoin",
            stableSymbol: "USDP-WETH",

            commonFeeCollector: COMMON_FEE_COLLECTOR,
            issuanceFeeCollector: ISSUANCE_FEE_COLLECTOR,

            collateral: COLLATERAL,
            chainlinkAggregator: CHAINLINK_AGGREGATOR,
            issuanceFeeBasisPoints: 90,
            stabilityFeePercent3Decimals: 900,
            liquidationFeePercent: 10,
            initialCollateralRatioPercent: 60,
            liquidationRatioPercent: 61,
            liquidationDiscountPercent3Decimals: 5000,
            devaluationPeriodSeconds: 3600 * 24 * 6,
        };

        const receipt1 = await this.factory.initDeploy(deployParameters);
        console.log("initDeploy: ", (await receipt1.wait()).gasUsed.toString());

        const deployId = (await this.factory.deploysCount()).toBigInt() - 1n;

        const receipt2 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage0: ", (await receipt2.wait()).gasUsed.toString());

        const receipt3 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage1: ", (await receipt3.wait()).gasUsed.toString());

        const receipt4 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage2: ", (await receipt4.wait()).gasUsed.toString());

        const receipt5 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage3: ", (await receipt5.wait()).gasUsed.toString());

        const receipt6 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage4: ", (await receipt6.wait()).gasUsed.toString());

        const receipt7 = await this.factory.continueDeploy(deployId);
        console.log("continueDeploy stage5: ", (await receipt7.wait()).gasUsed.toString());

        await expect(
            this.factory.continueDeploy(deployId)
        ).to.be.revertedWith("FACTORY: FINISHED");

        const deploy = await this.factory.getDeploy(deployId)
        expect(deploy.isFinished).to.be.equal(true);

        const usdp = await attachContract("USDP", deploy.usdp)
        expect(await usdp.name()).to.be.equal(deployParameters.stableName);
        expect(await usdp.symbol()).to.be.equal(deployParameters.stableSymbol);

        const vaultManagerBorrowFeeParameters = await attachContract("VaultManagerBorrowFeeParameters", deploy.vaultManagerBorrowFeeParameters)
        expect(await vaultManagerBorrowFeeParameters.getBorrowFee(COLLATERAL)).to.be.equal(deployParameters.issuanceFeeBasisPoints);
        expect(await vaultManagerBorrowFeeParameters.feeReceiver()).to.be.equal(deployParameters.issuanceFeeCollector);

        const collateralRegistry = await attachContract("CollateralRegistry", deploy.collateralRegistry);
        expect(await collateralRegistry.collaterals()).to.be.deep.equal([deployParameters.collateral])

        const chainlinkAggregator = await attachContract("ChainlinkedOracleMainAsset", deploy.chainlinkOracle);
        expect(await chainlinkAggregator.usdAggregators(COLLATERAL)).to.be.deep.equal(deployParameters.chainlinkAggregator)

        const vaultParameters = await attachContract("VaultParameters", deploy.vaultParameters);
        expect(await vaultParameters.foundation()).to.be.deep.equal(deployParameters.commonFeeCollector)
        expect(await vaultParameters.stabilityFee(COLLATERAL)).to.be.deep.equal(deployParameters.stabilityFeePercent3Decimals)
        expect(await vaultParameters.liquidationFee(COLLATERAL)).to.be.deep.equal(deployParameters.liquidationFeePercent)
        expect(await vaultParameters.tokenDebtLimit(COLLATERAL)).to.be.deep.equal(2n**256n-1n)

        const vaultManagerParameters = await attachContract("VaultManagerParameters", deploy.vaultManagerParameters);
        expect(await vaultManagerParameters.initialCollateralRatio(COLLATERAL)).to.be.deep.equal(deployParameters.initialCollateralRatioPercent)
        expect(await vaultManagerParameters.liquidationRatio(COLLATERAL)).to.be.deep.equal(deployParameters.liquidationRatioPercent)
        expect(await vaultManagerParameters.liquidationDiscount(COLLATERAL)).to.be.deep.equal(deployParameters.liquidationDiscountPercent3Decimals)
        expect(await vaultManagerParameters.devaluationPeriod(COLLATERAL)).to.be.deep.equal(deployParameters.devaluationPeriodSeconds)
    })

    it("check calculation of addresses for vault and vault parameters wih parallel deploy", async function () {
        const deployParameters = {
            stableName: "USDP-WETH stablecoin",
            stableSymbol: "USDP-WETH",

            commonFeeCollector: COMMON_FEE_COLLECTOR,
            issuanceFeeCollector: ISSUANCE_FEE_COLLECTOR,

            collateral: COLLATERAL,
            chainlinkAggregator: CHAINLINK_AGGREGATOR,
            issuanceFeeBasisPoints: 90,
            stabilityFeePercent3Decimals: 900,
            liquidationFeePercent: 10,
            initialCollateralRatioPercent: 60,
            liquidationRatioPercent: 61,
            liquidationDiscountPercent3Decimals: 5000,
            devaluationPeriodSeconds: 3600 * 24 * 6,
        };

        await this.factory.initDeploy(deployParameters);
        const deployId1 = (await this.factory.deploysCount()).toBigInt() - 1n;

        await this.factory.initDeploy(deployParameters);
        const deployId2 = (await this.factory.deploysCount()).toBigInt() - 1n;

        await this.factory.initDeploy(deployParameters);
        const deployId3 = (await this.factory.deploysCount()).toBigInt() - 1n;

        expect(await this.vaultDeployer.nonce()).to.be.equal(0);
        expect(await this.usdpVaultDeployer.nonce()).to.be.equal(0);

        await this.factory.continueDeploy(deployId1);
        await this.factory.continueDeploy(deployId2);
        await this.factory.continueDeploy(deployId3);
        await this.factory.continueDeploy(deployId1);
        await this.factory.continueDeploy(deployId2);
        await this.factory.continueDeploy(deployId3);

        expect(await this.vaultDeployer.nonce()).to.be.equal(3);
        expect(await this.usdpVaultDeployer.nonce()).to.be.equal(6);

        const deploy1 = await this.factory.getDeploy(deployId1)
        const deploy2 = await this.factory.getDeploy(deployId2)
        const deploy3 = await this.factory.getDeploy(deployId3)

        expect(deploy1.vault).not.to.be.equal(deploy2.vault);
        expect(deploy1.vault).not.to.be.equal(deploy3.vault);
        expect(deploy2.vault).not.to.be.equal(deploy3.vault);

        expect(deploy1.vaultParameters).not.to.be.equal(deploy2.vaultParameters);
        expect(deploy1.vaultParameters).not.to.be.equal(deploy3.vaultParameters);
        expect(deploy2.vaultParameters).not.to.be.equal(deploy3.vaultParameters);
    })

    it("check simple borrow and repay", async function () {
        const chainLinkUsdAggregator = await deployContract("ChainlinkAggregator_Mock", 250e8, 8);
        const collateral = await deployContract("DummyToken", "Token", "TKN", 18, ether('100000000000'));

        const deployParameters = {
            stableName: "USDP-WETH stablecoin",
            stableSymbol: "USDP-WETH",

            commonFeeCollector: COMMON_FEE_COLLECTOR,
            issuanceFeeCollector: ISSUANCE_FEE_COLLECTOR,

            collateral: collateral.address,
            chainlinkAggregator: chainLinkUsdAggregator.address,
            issuanceFeeBasisPoints: 90,
            stabilityFeePercent3Decimals: 0, // to simplify test
            liquidationFeePercent: 10,
            initialCollateralRatioPercent: 60,
            liquidationRatioPercent: 61,
            liquidationDiscountPercent3Decimals: 5000,
            devaluationPeriodSeconds: 3600 * 24 * 6,
        };

        await this.factory.initDeploy(deployParameters);
        const deployId = (await this.factory.deploysCount()).toBigInt() - 1n;

        await this.factory.continueDeploy(deployId);
        await this.factory.continueDeploy(deployId);
        await this.factory.continueDeploy(deployId);
        await this.factory.continueDeploy(deployId);
        await this.factory.continueDeploy(deployId);
        await this.factory.continueDeploy(deployId);

        const deploy = await this.factory.getDeploy(deployId)

        const cdpManager = await attachContract("CDPManager01", deploy.cdpManager);
        const usdp = await attachContract("USDP", deploy.usdp);
        const vault = await attachContract("Vault", deploy.vault);

        await collateral.approve(deploy.vault, ether('1'));
        await usdp.approve(deploy.cdpManager, ether('10'));

        await cdpManager.join(collateral.address, ether('1'), ether('150'));

        await expect(cdpManager.join(collateral.address, ether('0'), ether('100'))).to.be.revertedWith(
            'Unit Protocol: UNDERCOLLATERALIZED'
        );

        expect(await usdp.balanceOf(this.deployer.address)).to.be.equal(150n * 10n**18n * 9910n / 10000n)
        expect(await usdp.balanceOf(ISSUANCE_FEE_COLLECTOR)).to.be.equal(150n * 10n**18n * 90n / 10000n)

        expect(await collateral.balanceOf(deploy.vault)).to.be.equal(ether('1'));
        expect(await vault.debts(collateral.address, this.deployer.address)).to.be.equal(ether('150'));
        expect(await vault.collaterals(collateral.address, this.deployer.address)).to.be.equal(ether('1'));

        await cdpManager.exit(collateral.address, ether('0.5'), ether('75'));

        expect(await collateral.balanceOf(deploy.vault)).to.be.equal(ether('0.5'));
        expect(await vault.debts(collateral.address, this.deployer.address)).to.be.equal(ether('75'));
        expect(await vault.collaterals(collateral.address, this.deployer.address)).to.be.equal(ether('0.5'));
    })

    it("check deploy allowance", async function () {
        const deployParameters = {
            stableName: "USDP-WETH stablecoin",
            stableSymbol: "USDP-WETH",

            commonFeeCollector: COMMON_FEE_COLLECTOR,
            issuanceFeeCollector: ISSUANCE_FEE_COLLECTOR,

            collateral: COLLATERAL,
            chainlinkAggregator: CHAINLINK_AGGREGATOR,
            issuanceFeeBasisPoints: 90,
            stabilityFeePercent3Decimals: 900,
            liquidationFeePercent: 10,
            initialCollateralRatioPercent: 60,
            liquidationRatioPercent: 61,
            liquidationDiscountPercent3Decimals: 5000,
            devaluationPeriodSeconds: 3600 * 24 * 6,
        };


        await expect(
            this.factory.continueDeploy(0)
        ).to.be.revertedWith(
            'FACTORY: NOT_STARTED'
        );

        await expect(
            this.factory.connect(this.user1).initDeploy(deployParameters)
        ).to.be.revertedWith(
            'FACTORY: UNAUTHORIZED'
        );

        await this.factory.initDeploy(deployParameters);
        await this.factory.continueDeploy(0);

        await this.factory.setDeployOnlyForOwner(false);
        await this.factory.connect(this.user1).initDeploy(deployParameters)
    })

    it("check reinitialization of manager", async function () {
        await expect(
            this.vaultDeployer.setManager(COLLATERAL)
        ).to.be.revertedWith(
            'FACTORY: ALREADY_INITIALIZED'
        );
    })
});
