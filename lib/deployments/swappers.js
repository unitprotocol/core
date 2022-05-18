const {
    VAULT_PARAMETERS,
    WETH,
    USDP,
    USDT,
    CURVE_USDP_3CRV_POOL,
    CURVE_USDP_3CRV_POOL_USDP,
    CURVE_USDP_3CRV_POOL_USDT,
    CURVE_TRICRYPTO2_POOL,
    CURVE_TRICRYPTO2_POOL_USDT,
    CURVE_TRICRYPTO2_POOL_WETH
} = require("../../network_constants");

const createDeployment = async function(args) {
    let {deployer, vaultParameters, weth, usdp, usdt,
        usdp3crvPool, tricrypto2Pool,
    } = args;

    vaultParameters ??= VAULT_PARAMETERS;
    weth ??= WETH;
    usdp ??= USDP;
    usdt ??= USDT;
    usdp3crvPool ??= CURVE_USDP_3CRV_POOL;
    tricrypto2Pool ??= CURVE_TRICRYPTO2_POOL;

    const script = [
        [
            'SwapperWethViaCurve',
            vaultParameters, weth, usdp, usdt,
            usdp3crvPool, tricrypto2Pool,
        ],
        [
            'SwapperUniswapV2Lp',
            vaultParameters, weth, usdp,
            'SwapperWethViaCurve'
        ],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
