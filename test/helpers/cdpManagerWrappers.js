const {KEYDONIX_ORACLES_TYPES} = require("../../lib/constants");

function isKeydonix(context) {
    return KEYDONIX_ORACLES_TYPES.includes(context.collateralOracleType);
}

const FAKE_PROOF = ['0x01', '0x02', '0x03', '0x04'];

async function join(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).join(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function exit(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).exit(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function joinWithLeverage(context, user, asset, assetAmount, usdpAmount, minSwappedAssetAmount) {
    return cdpManager(context).connect(user).joinWithLeverage(
        asset.address, context.swapper.address, assetAmount, usdpAmount, minSwappedAssetAmount, ...getAdditionalParams(context)
    );
}

async function exitWithDeleverage(context, user, asset, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount) {
    return cdpManager(context).connect(user).exitWithDeleverage(
        asset.address, context.swapper.address, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount, ...getAdditionalParams(context)
    );
}

async function wrapAndJoin(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).wrapAndJoin(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function unwrapAndExit(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).unwrapAndExit(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function unwrapAndExitTargetRepayment(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).unwrapAndExitTargetRepayment(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function wrapAndJoinWithLeverage(context, user, asset, assetAmount, usdpAmount, minSwappedAssetAmount) {
    return cdpManager(context).connect(user).wrapAndJoinWithLeverage(
        asset.address, context.swapper.address, assetAmount, usdpAmount, minSwappedAssetAmount, ...getAdditionalParams(context)
    );
}

async function unwrapAndExitWithDeleverage(context, user, asset, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount) {
    return cdpManager(context).connect(user).unwrapAndExitWithDeleverage(
        asset.address, context.swapper.address, assetAmountToUser, assetAmountToSwap, minSwappedUsdpAmount, ...getAdditionalParams(context)
    );
}

async function triggerLiquidation(context, asset, user) {
    return cdpManager(context).triggerLiquidation(asset.address, user.address, ...getAdditionalParams(context));
}

/**
 * for using common code, for example events
 */
function cdpManager(context) {
    if (isKeydonix(context)) {
        return context.cdpManagerKeydonix;
    } else {
        return context.cdpManager;
    }
}

function getAdditionalParams(context) {
    if (isKeydonix(context)) {
        return [FAKE_PROOF];
    }

    return [];
}

module.exports = {
    cdpManagerWrapper: {
        join,
        exit,

        wrapAndJoin,
        unwrapAndExit,
        unwrapAndExitTargetRepayment,

        joinWithLeverage,
        exitWithDeleverage,
        wrapAndJoinWithLeverage,
        unwrapAndExitWithDeleverage,

        triggerLiquidation,
        cdpManager,
    }
}
