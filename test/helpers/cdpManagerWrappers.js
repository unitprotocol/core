const {KEYDONIX_ORACLES_TYPES} = require("../../lib/constants");

function isKeydonix(context) {
    return KEYDONIX_ORACLES_TYPES.includes(context.collateralOracleType);
}

const FAKE_PROOF = ['0x', '0x', '0x', '0x'];

async function join(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).join(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
}

async function exit(context, user, asset, assetAmount, usdpAmount) {
    return cdpManager(context).connect(user).exit(asset.address, assetAmount, usdpAmount, ...getAdditionalParams(context));
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
        triggerLiquidation,
        cdpManager,
    }
}
