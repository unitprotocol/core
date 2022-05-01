// temp script for testing wrapped sslp
//
// create key in alchemyapi.io
// run `npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<key>`
// run `npx hardhat --network localhost run scripts/deployTestWrappedSslp.js`
// connect with dapp

const {deployContract, attachContract, weiToEther, ether} = require("../test/helpers/ethersUtils");
const {ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, ORACLE_TYPE_WRAPPED_TO_UNDERLYING,
    ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX,
    PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION
} = require("../lib/constants");
const {createDeployment: createSwappersDeployment} = require("../lib/deployments/swappers");
const {runDeployment} = require("../test/helpers/deployUtils");
const {VAULT, VAULT_PARAMETERS, VAULT_MANAGER_PARAMETERS, ORACLE_REGISTRY, VAULT_MANAGER_BORROW_FEE_PARAMETERS,
    CDP_REGISTRY, USDP, WETH
} = require("../network_constants");
const {ethers} = require("hardhat");

const MULTISIG_ADDR = '0xae37E8f9a3f960eE090706Fa4db41Ca2f2C56Cb8'
const WRAPPED_ORACLE = '0x220Ea780a484c18fd0Ab252014c58299759a1Fbd'
const TOP_DOG = '0x94235659cf8b805b2c658f9ea2d6d6ddbb17c8d7'
const BONE_ADDR = '0x9813037ee2218799597d83d4a5b6f3b6778218d9'
const USDT_SSLP = '0x703b120F15Ab77B986a24c6f9262364d02f9432f'
const SHIB_SSLP = '0xCF6dAAB95c476106ECa715D48DE4b13287ffDEAa'
const TEST_WALLET = '0x8442e4fcbba519b4f4c1ea1fce57a5379c55906c'
const BONES_FEE = '0xB3E75687652D33D6F5CaD5B113619641E4F6535B'

async function deploy() {
    const [deployer, ] = await ethers.getSigners();

    const usdp = await attachContract('USDP', USDP);
    const weth = await attachContract('WETHMock', WETH);
    const vault = await attachContract('IVault', VAULT);
    const sslpUsdt = await attachContract('IERC20', USDT_SSLP);

    await ethers.provider.send("hardhat_impersonateAccount", [TEST_WALLET]);
    const testWallet = await ethers.getSigner(TEST_WALLET)
    await ethers.provider.send("hardhat_setBalance", [TEST_WALLET, '0x3635c9adc5dea00000' /* 1000Ether */]);

    await ethers.provider.send("hardhat_impersonateAccount", [MULTISIG_ADDR]);
    const multisig = await ethers.getSigner(MULTISIG_ADDR)
    await ethers.provider.send("hardhat_setBalance", [MULTISIG_ADDR, '0x3635c9adc5dea00000' /* 1000Ether */]);

    const vaultParameters = await attachContract('VaultParameters', VAULT_PARAMETERS);
    const cdpViewer = await attachContract('CDPViewer', "0x68af7bd6f3e2fb480b251cb1b508bbb406e8e21d");
    console.log("cdpViewer: " + cdpViewer.address)

    const swappersRegistry = await deployContract("SwappersRegistry", VAULT_PARAMETERS);

    //////// cdp manager ////////////////////////////////////////////
    // no keydonix since hardhat doesn't support proofs command
    const cdpManager = await deployContract("CDPManager01", VAULT_MANAGER_PARAMETERS, VAULT_MANAGER_BORROW_FEE_PARAMETERS, ORACLE_REGISTRY, CDP_REGISTRY, swappersRegistry.address);
    await vaultParameters.connect(multisig).setVaultAccess(cdpManager.address, true);

    console.log("cdpManager: " + cdpManager.address)
    //////// end of cdp manager ////////////////////////////////////////////


    //////// wrapped assets ////////////////////////////////////////////
    const wrappedSslpUsdt = await attachContract('WrappedShibaSwapLp', "0xce5147182624fd121d0ce974847a8dbfca9358b7")
    const wrappedSslpShib = await attachContract('WrappedShibaSwapLp', "0xa854f514f420a2b7b5d9ce65215da9204cdf2cae")

    console.log("wrappedSslpUsdt: " + wrappedSslpUsdt.address)
    console.log("sslp usdt: " + USDT_SSLP)
    console.log("wrappedSslpShib (keydonix): " + wrappedSslpShib.address)
    console.log("sslp shib: " + SHIB_SSLP)
    //////// end of wrapped assets ////////////////////////////////////////////


    //////// oracles ////////////////////////////////////////////
    const oracleRegistry = await attachContract('OracleRegistry', ORACLE_REGISTRY);
    const wrappedKeydonixOracle = await attachContract('WrappedToUnderlyingOracleKeydonix', "0xfF536BB145177D3E8E9A84fFF148B0e42282BF40");
    const wrappedOracle = await attachContract('WrappedToUnderlyingOracle', WRAPPED_ORACLE);

    await wrappedOracle.connect(multisig).setUnderlying(wrappedSslpUsdt.address, USDT_SSLP);//tx
    await wrappedKeydonixOracle.connect(multisig).setUnderlying(wrappedSslpShib.address, SHIB_SSLP);//tx

    await oracleRegistry.connect(multisig).setOracle(ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, wrappedKeydonixOracle.address);//tx

    await oracleRegistry.connect(multisig).setOracleTypeForAsset(wrappedSslpUsdt.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING)//tx
    await oracleRegistry.connect(multisig).setOracleTypeForAsset(wrappedSslpShib.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX)//tx

    await oracleRegistry.connect(multisig).setOracleTypeForAsset(USDT_SSLP, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN)
    await oracleRegistry.connect(multisig).setOracleTypeForAsset(SHIB_SSLP, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN_KEYDONIX)

    // console.log('oracles check')
    // const price = BigInt((await wrappedOracle.assetToUsd(wrappedSslpUsdt.address, '1000000000000000000')).toString()) / (BigInt(2)**BigInt(112)) / (BigInt(10)**BigInt(18));
    // console.log('wrapped usdt lp price', price)
    // const poolOracle = await attachContract('OraclePoolToken', '0xd88e1F40b6CD9793aa10A6C3ceEA1d01C2a507f9')
    // const price2 = BigInt((await poolOracle.assetToUsd(USDT_SSLP, '1000000000000000000')).toString()) / (BigInt(2)**BigInt(112)) / (BigInt(10)**BigInt(18));
    // console.log('usdt lp price', price2)
    //////// end of oracles ////////////////////////////////////////////


    //////// collaterals ////////////////////////////////////////////
    const vaultManagerParameters = await attachContract('VaultManagerParameters', VAULT_MANAGER_PARAMETERS);

    await vaultManagerParameters.connect(multisig).setCollateral(//tx
        wrappedSslpUsdt.address,
        '900', // stability fee
        '5', // liquidation fee
        '49', // initial collateralization
        '50', // liquidation ratio
        '0', // liquidation discount (3 decimals)
        '100', // devaluation period in blocks
        '1000000000000000000000', // debt limit
        [ORACLE_TYPE_WRAPPED_TO_UNDERLYING], // enabled oracles
        0,
        0,
    );
    await vaultManagerParameters.connect(multisig).setCollateral(//tx
        wrappedSslpShib.address,
        '900', // stability fee
        '5', // liquidation fee
        '49', // initial collateralization
        '50', // liquidation ratio
        '0', // liquidation discount (3 decimals)
        '100', // devaluation period in blocks
        '1000000000000000000000', // debt limit
        [ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX], // enabled oracles
        0,
        0,
    );

    // WARNING not for prod!! for testing of liquidations
    await vaultManagerParameters.connect(multisig).setInitialCollateralRatio(wrappedSslpUsdt.address, 100);
    await vaultManagerParameters.connect(multisig).setInitialCollateralRatio(wrappedSslpShib.address, 100);
    //////// end of collaterals ////////////////////////////////////////////


    //////// auction ////////////////////////////////////////////
    const parameters = await attachContract(
        'AssetsBooleanParameters',
        "0xcc33c2840b65c0a4ac4015c650dd20dc3eb2081d"
    );
    await parameters.connect(multisig).set('0x4bfB2FA13097E5312B19585042FdbF3562dC8676', PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, true);
    await parameters.connect(multisig).set('0x988AAf8B36173Af7Ad3FEB36EfEc0988Fbd06d07', PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, true);

    await parameters.connect(multisig).set(wrappedSslpShib.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);//tx
    await parameters.connect(multisig).set(wrappedSslpUsdt.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);//tx

    const auction = await attachContract('LiquidationAuction02', "0x9cCbb2F03184720Eef5f8fA768425AF06604Daf4")
    console.log("liquidation auction: ", auction.address)
    //////// end of auction ////////////////////////////////////////////

    //////// swappers ////////////////////////////////////////////
    const deployment = await createSwappersDeployment({deployer: deployer.address});
    const deployed = await runDeployment(deployment, {deployer: deployer.address, verify: false});
    const swapperLp = await attachContract('SwapperUniswapV2Lp', deployed.SwapperUniswapV2Lp);
    const swapperWeth = await attachContract('SwapperWethViaCurve', deployed.SwapperWethViaCurve);
    await swappersRegistry.connect(multisig).add(swapperLp.address);
    await swappersRegistry.connect(multisig).add(swapperWeth.address);
    //////// end of auction ////////////////////////////////////////////


    //////// cdp viewer check ////////////////////////////////////////////
    // console.log(await cdpViewer.getCollateralParameters(wrappedSslpUsdt.address, TEST_WALLET))
    // console.log(await cdpViewer.getTokenDetails(wrappedSslpUsdt.address, TEST_WALLET))
    //////// end of cdp viewer check ////////////////////////////////////////////

    //////// wsslp simple case ////////////////////////////////////////////
    // const bone = await attachContract('IERC20', BONE_ADDR)
    //
    // console.log('-- check wsslp')
    // const usdtSslp = await attachContract('IERC20', USDT_SSLP)
    // const balance = (await usdtSslp.balanceOf(TEST_WALLET)).toString();
    // console.log("balance of usdt sslp: ", balance)
    // console.log("balance of bone: ", (await bone.balanceOf(TEST_WALLET)).toString())
    //
    // await usdtSslp.connect(testWallet).approve(wrappedSslpUsdt.address, '1000000000000000000000');
    // await wrappedSslpUsdt.connect(testWallet).approve(VAULT, '1000000000000000000000');
    // await usdp.connect(testWallet).approve(cdpManager.address, '1000000000000000000000');
    //
    // await cdpManager.connect(testWallet).wrapAndJoin(wrappedSslpUsdt.address, balance, '50000000000000000000');
    //
    // console.log('claimable bones: ', (await wrappedSslpUsdt.pendingReward(testWallet.address)).toString())
    // await network.provider.send("evm_mine");
    // await network.provider.send("evm_mine");
    // console.log('claimable bones after 2 blocks: ', (await wrappedSslpUsdt.pendingReward(testWallet.address)).toString())
    // console.log('bones fees wallet balance before claim: ', (await bone.balanceOf(BONES_FEE)).toString())
    // await wrappedSslpUsdt.connect(testWallet).claimReward(testWallet.address)
    // console.log("balance of bone: ", (await bone.balanceOf(TEST_WALLET)).toString())
    // console.log('bones fees wallet balance after claim: ', (await bone.balanceOf(BONES_FEE)).toString())
    //////// end of wsslp simple case ////////////////////////////////////////////

    //////// weth leverage ////////////////////////////////////////////
    // console.log('-- check simple leverage')
    // await vaultParameters.connect(multisig).setTokenDebtLimit(weth.address, ether('10000000'));
    // const assetAmount = ether('1');
    // const usdpAmount = ether('3000'); // leverage >2 atm
    //
    // await weth.connect(testWallet).deposit({value: assetAmount});
    //
    // const wethBalance1 = await weth.balanceOf(TEST_WALLET);
    // const usdpBalance1 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition1 = await vault.collaterals(weth.address, TEST_WALLET);
    // const debt1 = await vault.debts(weth.address, TEST_WALLET);
    // console.log(`balances before: weth ${weiToEther(wethBalance1)}, usdp ${weiToEther(usdpBalance1)}`);
    // console.log(`position before: ${weiToEther(vaultPosition1)}, debt: ${weiToEther(debt1)}`);
    //
    // await usdp.connect(testWallet).approve(cdpManager.address, ether('5000')); // borrow fee
    // await weth.connect(testWallet).approve(VAULT, ether('5000')); // borrow
    // await usdp.connect(testWallet).approve(swapperWeth.address, ether('5000')); // swap
    // await weth.connect(testWallet).approve(swapperWeth.address, ether('5000')); // swap
    //
    // const predictedWeth = await swapperWeth.predictAssetOut(weth.address, usdpAmount);
    // await cdpManager.connect(testWallet).joinWithLeverage(weth.address, swapperWeth.address, assetAmount, usdpAmount, predictedWeth.mul(99).div(100));
    //
    // const wethBalance2 = await weth.balanceOf(TEST_WALLET);
    // const usdpBalance2 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition2 = await vault.collaterals(weth.address, TEST_WALLET);
    // const debt2 = await vault.debts(weth.address, TEST_WALLET);
    // console.log(`balances after: weth ${weiToEther(wethBalance2)}, usdp ${weiToEther(usdpBalance2)}`);
    // console.log(`position after: ${weiToEther(vaultPosition2)}, debt: ${weiToEther(debt2)}, diff: ${weiToEther(vaultPosition2.sub(vaultPosition1))}`);
    //
    // assert(wethBalance1.sub(assetAmount).eq(wethBalance2));
    // assert(usdpBalance1.eq(usdpBalance2));
    // assert(vaultPosition2.sub(vaultPosition1).gt(assetAmount));
    //
    // console.log('-- deleverage')
    // const predictedUsdp = await swapperWeth.predictUsdpOut(weth.address, assetAmount.div(2));
    // await cdpManager.connect(testWallet).exitWithDeleverage(weth.address, swapperWeth.address, assetAmount.div(2), assetAmount.div(2), predictedUsdp.mul(99).div(100));
    //
    // const wethBalance3 = await weth.balanceOf(TEST_WALLET);
    // const usdpBalance3 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition3 = await vault.collaterals(weth.address, TEST_WALLET);
    // const debt3 = await vault.debts(weth.address, TEST_WALLET);
    // console.log(`balances after: weth ${weiToEther(wethBalance3)}, usdp ${weiToEther(usdpBalance3)}`);
    // console.log(`position after: ${weiToEther(vaultPosition3)}, debt: ${weiToEther(debt3)}`);
    //
    //
    // assert(wethBalance3.sub(wethBalance2).eq(assetAmount.div(2)));
    // assert(usdpBalance3.eq(usdpBalance2) || usdpBalance3.sub(1).eq(usdpBalance2)); // principal could be less then repayment (by1)
    // assert(vaultPosition3.add(assetAmount).eq(vaultPosition2));
    //////// end of wsslp simple case ////////////////////////////////////////////


    //////// wrapped asset leverage ////////////////////////////////////////////
    // console.log('-- check simple leverage')
    // const assetAmount = ether('0.0000005');
    // const usdpAmount = ether('150'); // leverage >2 atm
    //
    // const wsslpBalance1 = await wrappedSslpUsdt.balanceOf(TEST_WALLET);
    // const sslpBalance1 = await sslpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance1 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition1 = await vault.collaterals(wrappedSslpUsdt.address, TEST_WALLET);
    // const debt1 = await vault.debts(wrappedSslpUsdt.address, TEST_WALLET);
    // console.log(`balances before: sslp ${weiToEther(sslpBalance1)}, wsslp ${weiToEther(wsslpBalance1)}, usdp ${weiToEther(usdpBalance1)}`);
    // console.log(`position before: ${weiToEther(vaultPosition1)}, debt: ${weiToEther(debt1)}`);
    //
    // await sslpUsdt.connect(testWallet).approve(wrappedSslpUsdt.address, ether('5000')); // wrap
    // await usdp.connect(testWallet).approve(cdpManager.address, ether('5000')); // borrow fee
    // await wrappedSslpUsdt.connect(testWallet).approve(VAULT, ether('5000')); // borrow
    // await usdp.connect(testWallet).approve(swapperLp.address, ether('5000')); // swap
    // await sslpUsdt.connect(testWallet).approve(swapperLp.address, ether('5000')); // swap back
    //
    // const predictedWeth = await swapperLp.predictAssetOut(sslpUsdt.address, usdpAmount);
    // await cdpManager.connect(testWallet).wrapAndJoinWithLeverage(wrappedSslpUsdt.address, swapperLp.address, assetAmount, usdpAmount, predictedWeth.mul(99).div(100));
    //
    // const wsslpBalance2 = await wrappedSslpUsdt.balanceOf(TEST_WALLET);
    // const sslpBalance2 = await sslpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance2 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition2 = await vault.collaterals(wrappedSslpUsdt.address, TEST_WALLET);
    // const debt2 = await vault.debts(wrappedSslpUsdt.address, TEST_WALLET);
    // console.log(`balances after: sslp ${weiToEther(sslpBalance2)}, wsslp ${weiToEther(wsslpBalance2)}, usdp ${weiToEther(usdpBalance2)}`);
    // console.log(`position after: ${weiToEther(vaultPosition2)}, debt: ${weiToEther(debt2)}, diff: ${weiToEther(vaultPosition2.sub(vaultPosition1))}`);
    //
    // assert(sslpBalance1.sub(assetAmount).eq(sslpBalance2))
    // assert(wsslpBalance2.eq(wsslpBalance1));
    // assert(usdpBalance1.eq(usdpBalance2));
    // assert(vaultPosition2.sub(vaultPosition1).gt(assetAmount));
    //
    // console.log('-- deleverage')
    // const predictedUsdp = await swapperLp.predictUsdpOut(sslpUsdt.address, assetAmount.div(2));
    // await cdpManager.connect(testWallet).unwrapAndExitWithDeleverage(wrappedSslpUsdt.address, swapperLp.address, assetAmount.div(2), assetAmount.div(2), predictedUsdp.mul(99).div(100));
    //
    // const wsslpBalance3 = await wrappedSslpUsdt.balanceOf(TEST_WALLET);
    // const sslpBalance3 = await sslpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance3 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition3 = await vault.collaterals(wrappedSslpUsdt.address, TEST_WALLET);
    // const debt3 = await vault.debts(wrappedSslpUsdt.address, TEST_WALLET);
    // console.log(`balances after: sslp ${weiToEther(sslpBalance3)}, wsslp ${weiToEther(wsslpBalance3)}, usdp ${weiToEther(usdpBalance3)}`);
    // console.log(`position after: ${weiToEther(vaultPosition3)}, debt: ${weiToEther(debt3)}`);
    //
    //
    // assert(sslpBalance3.sub(sslpBalance2).eq(assetAmount.div(2)));
    // assert(usdpBalance3.eq(usdpBalance2) || usdpBalance3.sub(1).eq(usdpBalance2));
    // assert(vaultPosition3.add(assetAmount).eq(vaultPosition2));
    //////// end of wrapped asset leverage ////////////////////////////////////////////
}


deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

