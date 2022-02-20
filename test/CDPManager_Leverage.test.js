const {expect} = require("chai");
const {ethers} = require("hardhat");
const {
    prepareCoreContracts, CASE_CHAINLINK, CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX,
    CASE_WRAPPED_TO_UNDERLYING_CHAINLINK, CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX,
} = require("./helpers/deploy");
const {cdpManagerWrapper} = require("./helpers/cdpManagerWrappers");
const {ether, BN, deployContract} = require("./helpers/ethersUtils");
const {ZERO_ADDRESS} = require("./helpers/deployUtils");

const oracleCases = [
    [CASE_CHAINLINK, 'cdp manager', false],
    [CASE_UNISWAP_V2_MAIN_ASSET_KEYDONIX, 'cdp manager keydonix', false],
    [CASE_WRAPPED_TO_UNDERLYING_CHAINLINK, 'wrapped assets: cdp manager', true],
    [CASE_WRAPPED_TO_UNDERLYING_SIMPLE_KEYDONIX, 'wrappedassets: cdp manager keydonix', true],
]

let context = {};
oracleCases.forEach(params =>
    describe(`${params[1]}: leverage and deleverage`, function () {

        beforeEach(async function () {
            context.isWrappedAsset = params[2];
            [context.deployer, context.user1, context.user2, context.user3, context.manager] = await ethers.getSigners();

            if (context.isWrappedAsset) {
                const collateral = await deployContract("WrappedAssetMock", ZERO_ADDRESS);
                await prepareCoreContracts(context, params[0], {collateral});
                await context.collateral.setUnderlyingToken(context.collateralWrappedAssetUnderlying.address);
            } else {
                await prepareCoreContracts(context, params[0]);
            }

            await context.swapper.tests_setAssetToUsdpRate(500); // standard rate in tests 1 token = 500usd

            // allowances
            if (context.isWrappedAsset) {
                await context.collateralWrappedAssetUnderlying.connect(context.user1).approve(context.swapper.address, ether('10000')); // swaps asset to usdp
                await context.collateralWrappedAssetUnderlying.connect(context.user1).approve(context.collateral.address, ether('10000')); // wrap asset
            } else {
                await context.collateral.connect(context.user1).approve(context.swapper.address, ether('10000')); // swaps asset to usdp
            }
            await context.collateral.connect(context.user1).approve(context.vault.address, ether('10000')); // borrow: send to vault
            await context.usdp.connect(context.user1).approve(context.swapper.address, ether('10000')); // swaps usp to asset
            await context.usdp.connect(context.user1).approve(context.vault.address, ether('10000')); // borrow: stability fee
        });

        describe("leverage", function () {
            it(`simple leverage`, async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await mintCollateral(context.user1, assetAmount);

                await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                await checkUserAssetBalance(0);
            });

            it('to big leverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('2000'); // leverage 4
                const minSwappedAssetAmount = ether('4');

                await mintCollateral(context.user1, assetAmount);

                // 2000 / ((4+1)*500) = 80% > ILR (75%)
                await expect(
                    joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount)
                ).to.be.revertedWith("UNDERCOLLATERALIZED")
            });

            it('to big leverage after asset deposit', async function () {
                const initialAssetAmount = ether('0.334');
                const assetAmount = ether('1');
                const usdpAmount = ether('2000'); // leverage 4
                const minSwappedAssetAmount = ether('4');

                await mintCollateral(context.user1, ether('1.334'));
                await join(context.user1, initialAssetAmount, 0);

                // 2000 / ((4+1+0.334)*500) = 74.99% < ILR (75%)
                await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount).add(initialAssetAmount));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                await checkUserAssetBalance(0);
            });
        })

        describe("deleverage", function () {
            it('simple deleverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await mintCollateral(context.user1, assetAmount);
                await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);

                // debt 1000
                // collaterals 3
                await exitWithDeleverage(context.user1, assetAmount, minSwappedAssetAmount, usdpAmount);
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(0);
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(0);

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                await checkUserAssetBalance(assetAmount);
            });

            it('partial deleverage', async function () {
                const assetAmount = ether('1');
                const usdpAmount = ether('1000'); // leverage 2
                const minSwappedAssetAmount = ether('2');

                await mintCollateral(context.user1, assetAmount);
                await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);

                // debt 1000
                // collaterals 3
                await exitWithDeleverage(context.user1, 0, minSwappedAssetAmount.div(2), usdpAmount.div(2));
                expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(usdpAmount.div(2));
                expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount.add(minSwappedAssetAmount.div(2)));

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                await checkUserAssetBalance(0);
            });

            [0, 3600, 3600*5].forEach(interval =>
                it(`deleverage with stability fee (target repayment) with repayment after ${interval} seconds`, async function () {
                    const assetAmount = ether('1');
                    const usdpAmount = ether('1000'); // leverage 2
                    const minSwappedAssetAmount = ether('2');

                    await context.vaultParameters.setStabilityFee(context.collateral.address, 1000); // 1%

                    await mintCollateral(context.user1, assetAmount);
                    await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);
                    const block1Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    await network.provider.send("evm_increaseTime", [interval]);

                    // debt 1000
                    // collaterals 3
                    await exitWithDeleverage(context.user1, 0, minSwappedAssetAmount, usdpAmount);
                    const block2Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    const fee = usdpAmount.mul(1000 /*1%*/).mul(block2Timestamp - block1Timestamp).div(365*24*3600).div(100000);

                    expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(fee); // not repaid since also some fee was paid
                    expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(assetAmount);

                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.closeTo(BN(0), BN(1)); // rounding error on repayment calculation, not more 1 "wei"
                    expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                    await checkUserAssetBalance(0);
                })
            );

            [0, 3600, 3600*5].forEach(interval =>
                it(`deleverage with stability fee and repayment more than debt with repayment after ${interval} seconds`, async function () {
                    const assetAmount = ether('1');
                    const usdpAmount = ether('1000'); // leverage 2
                    const minSwappedAssetAmount = ether('2');
                    const usdpAmountToRepay = ether('1250');

                    await context.vaultParameters.setStabilityFee(context.collateral.address, 1000); // 1%

                    await mintCollateral(context.user1, assetAmount);
                    await joinWithLeverage(context.user1, assetAmount, usdpAmount, minSwappedAssetAmount);
                    const block1Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    await network.provider.send("evm_increaseTime", [interval]);

                    // debt 1000, collaterals 3
                    // but try to repay 1250 with selling of 2.5 collaterals
                    await exitWithDeleverage(context.user1, 0, ether('2.5'), usdpAmountToRepay);
                    const block2Timestamp = (await ethers.provider.getBlock("latest")).timestamp;

                    const fee = usdpAmount.mul(1000 /*1%*/).mul(block2Timestamp - block1Timestamp).div(365*24*3600).div(100000);

                    expect(await context.vault.debts(context.collateral.address, context.user1.address)).to.be.equal(0);
                    expect(await context.vault.collaterals(context.collateral.address, context.user1.address)).to.be.equal(ether('0.5'));

                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmountToRepay.sub(usdpAmount).sub(fee));
                    expect(await context.usdp.balanceOf(context.vault.address)).to.be.equal(0);

                    await checkUserAssetBalance(0);
                })
            );
        })
    })
);

async function join(user, assetAmount, usdpAmount) {
    if (context.isWrappedAsset) {
        return cdpManagerWrapper.wrapAndJoin(context, user, context.collateral, assetAmount, usdpAmount);
    } else {
        return cdpManagerWrapper.join(context, user, context.collateral, assetAmount, usdpAmount);
    }
}

async function joinWithLeverage(user, assetAmount, usdpAmount, minSwappedAssetAmount) {
    if (context.isWrappedAsset) {
        return cdpManagerWrapper.wrapAndJoinWithLeverage(context, user, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
    } else {
        return cdpManagerWrapper.joinWithLeverage(context, user, context.collateral, assetAmount, usdpAmount, minSwappedAssetAmount);
    }
}

async function exitWithDeleverage(user, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount) {
    if (context.isWrappedAsset) {
        return cdpManagerWrapper.unwrapAndExitWithDeleverage(context, user,  context.collateral, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount);
    } else {
        return cdpManagerWrapper.exitWithDeleverage(context, user,  context.collateral, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount);
    }
}

async function mintCollateral(user, assetAmount) {
    if (context.isWrappedAsset) {
        return context.collateralWrappedAssetUnderlying.tests_mint(user.address, assetAmount);
    } else {
        return context.collateral.tests_mint(user.address, assetAmount);
    }
}

async function checkUserAssetBalance(assetAmount) {
    if (context.isWrappedAsset) {
        return expect(await context.collateralWrappedAssetUnderlying.balanceOf(context.user1.address)).to.be.equal(assetAmount);
    } else {
        return expect(await context.collateral.balanceOf(context.user1.address)).to.be.equal(assetAmount);
    }
}