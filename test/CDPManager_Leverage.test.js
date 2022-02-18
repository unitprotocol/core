const {expect} = require("chai");
const {ethers} = require("hardhat");
const {
    prepareCoreContracts, CASE_CHAINLINK, CASE_KEYDONIX_MAIN_ASSET
} = require("./helpers/deploy");
const {cdpManagerWrapper} = require("./helpers/cdpManagerWrappers");
const {ether, BN} = require("./helpers/ethersUtils");

const oracleCases = [
    [CASE_CHAINLINK, 'cdp manager'],
    [CASE_KEYDONIX_MAIN_ASSET, 'cdp manager keydonix'],
]

let context = {};
oracleCases.forEach(params =>
    describe(`${params[1]}: leverage and deleverage`, function () {

        beforeEach(async function () {
            [context.deployer, context.user1, context.user2, context.user3, context.manager] = await ethers.getSigners();
            await prepareCoreContracts(context, params[0]);

            await context.swapper.tests_setAssetToUsdpRate(500); // standard rate in tests 1 token = 500usd

            // allowances
            await context.collateral.connect(context.user1).approve(context.swapper.address, ether('10000')); // swaps
            await context.usdp.connect(context.user1).approve(context.swapper.address, ether('10000')); // swaps
            await context.collateral.connect(context.user1).approve(context.vault.address, ether('10000')); // borrow
            await context.usdp.connect(context.user1).approve(context.vault.address, ether('10000')); // borrow: stability fee
        });

        describe("leverage", function () {
            it(`simple leverage`, async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await context.collateral.tests_mint(context.user1.address, assetAmount);

                await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(0);
            });

            it('to big leverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('2000'); // leverage 4
                const minSwappedAssetAmount = ether('4');

                await context.collateral.tests_mint(context.user1.address, assetAmount);

                // 2000 / ((4+1)*500) = 80% > ILR (75%)
                await expect(
                    cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount)
                ).to.be.revertedWith("UNDERCOLLATERALIZED")
            });

            it('to big leverage after asset deposit', async function () {
                const initialAssetAmount = ether('0.334');
                const assetAmount = ether('1');
                const usdpAmount = ether('2000'); // leverage 4
                const minSwappedAssetAmount = ether('4');

                await context.collateral.tests_mint(context.user1.address, ether('1.334'));
                await cdpManagerWrapper.join(context, context.user1, context.collateral, initialAssetAmount, 0);

                // 2000 / ((4+1+0.334)*500) = 74.99% < ILR (75%)
                await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount).add(initialAssetAmount));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(0);
            });
        })

        describe("deleverage", function () {
            it('simple deleverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await context.collateral.tests_mint(context.user1.address, assetAmount);
                await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);

                // debt 1000
                // collaterals 3
                await cdpManagerWrapper.exitWithDeleverage(context, context.user1, context.collateral, assetAmount, minSwappedAssetAmount, usdpAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(0);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(0);

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(assetAmount);
            });

            it('partial deleverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await context.collateral.tests_mint(context.user1.address, assetAmount);
                await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);

                // debt 1000
                // collaterals 3
                await cdpManagerWrapper.exitWithDeleverage(context, context.user1, context.collateral, 0, minSwappedAssetAmount.div(2), usdpAmount.div(2));
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount.div(2));
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount.div(2)));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(0);
            });

            [0, 3600, 3600*5].forEach(interval =>
                it(`deleverage with stability fee (target repayment) with repayment after ${interval} seconds`, async function () {
                    const assetAmount = ether('1');
                    const usdpAmount = ether('1000'); // leverage 2
                    const minSwappedAssetAmount = ether('2');

                    await context.vaultParameters.setStabilityFee(context.collateral.address, 1000); // 1%

                    await context.collateral.tests_mint(context.user1.address, assetAmount);
                    await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
                    const block1Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    await network.provider.send("evm_increaseTime", [interval]);

                    // debt 1000
                    // collaterals 3
                    await cdpManagerWrapper.exitWithDeleverage(context, context.user1, context.collateral, 0, minSwappedAssetAmount, usdpAmount);
                    const block2Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    const fee = usdpAmount.mul(1000 /*1%*/).mul(block2Timestamp - block1Timestamp).div(365*24*3600).div(100000);

                    expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(fee); // not repaid since also some fee was paid
                    expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount);

                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.closeTo(BN(0), BN(1)); // rounding error on repayment calculation, not more 1 "wei"
                    expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                    expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(0);
                })
            );

            [0, 3600, 3600*5].forEach(interval =>
                it(`deleverage with stability fee and repayment more than debt with repayment after ${interval} seconds`, async function () {
                    const assetAmount = ether('1');
                    const usdpAmount = ether('1000'); // leverage 2
                    const minSwappedAssetAmount = ether('2');
                    const usdpAmountToRepay = ether('1250');

                    await context.vaultParameters.setStabilityFee(context.collateral.address, 1000); // 1%

                    await context.collateral.tests_mint(context.user1.address, assetAmount);
                    await cdpManagerWrapper.joinWithLeverage(context, context.user1, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
                    const block1Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    await network.provider.send("evm_increaseTime", [interval]);

                    // debt 1000, collaterals 3
                    // but try to repay 1250 with selling of 2.5 collaterals
                    await cdpManagerWrapper.exitWithDeleverage(context, context.user1, context.collateral, 0, ether('2.5'), usdpAmountToRepay);
                    const block2Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    const fee = usdpAmount.mul(1000 /*1%*/).mul(block2Timestamp - block1Timestamp).div(365*24*3600).div(100000);

                    expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(0);
                    expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(ether('0.5'));

                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmountToRepay.sub(usdpAmount).sub(fee));
                    expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                    expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(0);
                })
            );
        })
    })
);