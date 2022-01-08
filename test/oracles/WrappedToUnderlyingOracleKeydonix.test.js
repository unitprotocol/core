const {expect} = require("chai");
const {ethers} = require("hardhat");
const {prepareCoreContracts} = require("../helpers/deploy");
const {deployContract} = require("../helpers/ethersUtils");
const {ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING} = require("../../lib/constants");

const SIMPLE_ORACLE_ID = 500;
const WRAPPED_ASSET = '0x0000000000000000000000000000000000000001';
const UNDERLYING_ASSET = '0x0000000000000000000000000000000000000002';

let context;

describe(`oracle WrappedToUnderlyingOracleKeydonix.test.js`, function () {

    beforeEach(async function () {
        context = this;

        [this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();
        await prepareCoreContracts(this);

        const keydonixSimpleOracle = await deployContract('KeydonixSimpleOracle_Mock');
        await context.oracleRegistry.setOracle(SIMPLE_ORACLE_ID, keydonixSimpleOracle.address);
        await context.oracleRegistry.setOracleTypeForAsset(UNDERLYING_ASSET, SIMPLE_ORACLE_ID);

        this.oracleKeydonixWrappedToUnderlying = await deployContract('WrappedToUnderlyingOracleKeydonix', context.vaultParameters.address, context.oracleRegistry.address);
        await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING, this.oracleKeydonixWrappedToUnderlying.address);
        await context.oracleRegistry.setOracleTypeForAsset(WRAPPED_ASSET, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING);
        await this.oracleKeydonixWrappedToUnderlying.setUnderlying(WRAPPED_ASSET, UNDERLYING_ASSET)
    });

    it("wrapped to keydonix", async function () {
        expect(await this.oracleKeydonixWrappedToUnderlying.assetToUsd(WRAPPED_ASSET, 2, ['0x01', '0x02', '0x03', '0x04'])).to.be.equal(2468);
    });

    const cases = [
        [['0x00', '0x02', '0x03', '0x04'], 'Unit Protocol: proofData.block'],
        [['0x01', '0x00', '0x03', '0x04'], 'Unit Protocol: proofData.accountProofNodesRlp'],
        [['0x01', '0x02', '0x00', '0x04'], 'Unit Protocol: proofData.reserveAndTimestampProofNodesRlp'],
        [['0x01', '0x02', '0x03', '0x00'], 'Unit Protocol: proofData.priceAccumulatorProofNodesRlp'],
    ]
    cases.forEach((params, i) =>
        it(`check correct passing proof for proof part ${i}`, async function () {
            await expect(
                this.oracleKeydonixWrappedToUnderlying.assetToUsd(WRAPPED_ASSET, 2, params[0])
            ).to.be.revertedWith(params[1]);
        })
    );

    it(`check with non keydonix underlying oracle`, async function () {
        const simpleOracle = await deployContract('SimpleOracle_Mock');
        await context.oracleRegistry.setOracle(SIMPLE_ORACLE_ID, simpleOracle.address);
        await context.oracleRegistry.setOracleTypeForAsset(UNDERLYING_ASSET, SIMPLE_ORACLE_ID);

        this.oracleKeydonixWrappedToUnderlying = await deployContract('WrappedToUnderlyingOracleKeydonix', context.vaultParameters.address, context.oracleRegistry.address);
        await context.oracleRegistry.setOracle(ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING, this.oracleKeydonixWrappedToUnderlying.address);
        await context.oracleRegistry.setOracleTypeForAsset(WRAPPED_ASSET, ORACLE_TYPE_UNISWAP_V2_KEYDONIX_WRAPPED_TO_UNDERLYING);
        await this.oracleKeydonixWrappedToUnderlying.setUnderlying(WRAPPED_ASSET, UNDERLYING_ASSET)

        await expect(
            this.oracleKeydonixWrappedToUnderlying.assetToUsd(WRAPPED_ASSET, 2, ['0x01', '0x02', '0x03', '0x04'])
        ).to.be.revertedWith("function selector was not recognized and there's no fallback function");
    })

});
