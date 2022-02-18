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
        usdp3crvPool, usdp3crvPoolUsdpIndex, usdp3crvPoolUsdtIndex,
        tricrypto2Pool, tricrypto2PoolUsdtIndex, tricrypto2PoolWethIndex,
    } = args;

    vaultParameters = vaultParameters ?? VAULT_PARAMETERS;
    weth = weth ?? WETH;
    usdp = usdp ?? USDP;
    usdt = usdt ?? USDT;
    usdp3crvPool = usdp3crvPool ?? CURVE_USDP_3CRV_POOL;
    usdp3crvPoolUsdpIndex = usdp3crvPoolUsdpIndex ?? CURVE_USDP_3CRV_POOL_USDP;
    usdp3crvPoolUsdtIndex = usdp3crvPoolUsdtIndex ?? CURVE_USDP_3CRV_POOL_USDT;
    tricrypto2Pool = tricrypto2Pool ?? CURVE_TRICRYPTO2_POOL;
    tricrypto2PoolUsdtIndex = tricrypto2PoolUsdtIndex ?? CURVE_TRICRYPTO2_POOL_USDT;
    tricrypto2PoolWethIndex = tricrypto2PoolWethIndex ?? CURVE_TRICRYPTO2_POOL_WETH;

    const script = [
        [
            'SwapperWethViaCurve',
            vaultParameters, weth, usdp, usdt,
            usdp3crvPool, usdp3crvPoolUsdpIndex, usdp3crvPoolUsdtIndex,
            tricrypto2Pool, tricrypto2PoolUsdtIndex, tricrypto2PoolWethIndex,
        ],
        [
            'SwapperUniswapV2Lp',
            vaultParameters, weth, usdp, usdt,
            usdp3crvPool, usdp3crvPoolUsdpIndex, usdp3crvPoolUsdtIndex,
            tricrypto2Pool, tricrypto2PoolUsdtIndex, tricrypto2PoolWethIndex,
        ],
    ];

    return script;
};


module.exports = {
	createDeployment,
};
