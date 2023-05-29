// temp script for testing wrapped slp
//
// create key in alchemyapi.io
// run `npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<key>`
// run `npx hardhat --network localhost run scripts/deployTestWrappedSslp.js`
// connect with dapp

const {deployContract, attachContract, weiToEther, ether} = require("../test/helpers/ethersUtils");
const {ORACLE_TYPE_WRAPPED_TO_UNDERLYING_KEYDONIX, ORACLE_TYPE_WRAPPED_TO_UNDERLYING,
    ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN,
    PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION
} = require("../lib/constants");
const {createDeployment: createSwappersDeployment} = require("../lib/deployments/swappers");
const {runDeployment} = require("../test/helpers/deployUtils");
const {VAULT, VAULT_PARAMETERS, VAULT_MANAGER_PARAMETERS, ORACLE_REGISTRY, VAULT_MANAGER_BORROW_FEE_PARAMETERS,
    CDP_REGISTRY, USDP, WETH, ORACLE_WRAPPED_TO_UNDERLYING, MULTISIG_CONTROL, TEST_WALLET, MULTISIG_FEE
} = require("../network_constants");
const {ethers} = require("hardhat");


const REWARD_DISTRIBUTOR = '0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd'
const REWARD_TOKEN = '0x6b3595068778dd592e39a122f4f5a5cf09c90fe2'
const USDT_SLP = '0x06da0fd433C1A5d7a4faa01111c044910A184553'

async function deploy() {
    const [deployer, ] = await ethers.getSigners();

    const usdp = await attachContract('USDP', USDP);
    const weth = await attachContract('WETHMock', WETH);
    const vault = await attachContract('IVault', VAULT);
    const slpUsdt = await attachContract('IERC20', USDT_SLP);

    await ethers.provider.send("hardhat_impersonateAccount", [TEST_WALLET]);
    const testWallet = await ethers.getSigner(TEST_WALLET)
    await ethers.provider.send("hardhat_setBalance", [TEST_WALLET, '0x3635c9adc5dea00000' /* 1000Ether */]);

    await ethers.provider.send("hardhat_impersonateAccount", [MULTISIG_CONTROL]);
    const multisig = await ethers.getSigner(MULTISIG_CONTROL)
    await ethers.provider.send("hardhat_setBalance", [MULTISIG_CONTROL, '0x3635c9adc5dea00000' /* 1000Ether */]);

    const vaultParameters = await attachContract('VaultParameters', VAULT_PARAMETERS);

    const swappersRegistry = await deployContract("SwappersRegistry", VAULT_PARAMETERS);

    //////// cdp manager ////////////////////////////////////////////
    // no keydonix since hardhat doesn't support proofs command
    const cdpManager = await deployContract("CDPManager01", VAULT_MANAGER_PARAMETERS, VAULT_MANAGER_BORROW_FEE_PARAMETERS, ORACLE_REGISTRY, CDP_REGISTRY, swappersRegistry.address);
    await vaultParameters.connect(multisig).setVaultAccess(cdpManager.address, true);

    console.log("cdpManager: " + cdpManager.address)
    //////// end of cdp manager ////////////////////////////////////////////


    //////// wrapped assets ////////////////////////////////////////////
    const wrappedSlpUsdt = await deployContract('WrappedSushiSwapLp', VAULT_PARAMETERS, REWARD_DISTRIBUTOR, 0, MULTISIG_FEE);

    console.log("wrappedSlpUsdt: " + wrappedSlpUsdt.address)
    console.log("sslp usdt: " + USDT_SLP)
    //////// end of wrapped assets ////////////////////////////////////////////


    //////// oracles ////////////////////////////////////////////
    const oracleRegistry = await attachContract('OracleRegistry', ORACLE_REGISTRY);
    const wrappedOracle = await attachContract('WrappedToUnderlyingOracle', ORACLE_WRAPPED_TO_UNDERLYING);

    await wrappedOracle.connect(multisig).setUnderlying(wrappedSlpUsdt.address, USDT_SLP);

    await oracleRegistry.connect(multisig).setOracleTypeForAsset(wrappedSlpUsdt.address, ORACLE_TYPE_WRAPPED_TO_UNDERLYING)

    await oracleRegistry.connect(multisig).setOracleTypeForAsset(USDT_SLP, ORACLE_TYPE_UNISWAP_V2_POOL_TOKEN)

    console.log('oracles check')
    const price = BigInt((await wrappedOracle.assetToUsd(wrappedSlpUsdt.address, '1000000000000000000')).toString()) / (BigInt(2)**BigInt(112)) / (BigInt(10)**BigInt(18));
    console.log('wrapped usdt lp price', price)
    const poolOracle = await attachContract('OraclePoolToken', '0xd88e1F40b6CD9793aa10A6C3ceEA1d01C2a507f9')
    const price2 = BigInt((await poolOracle.assetToUsd(USDT_SLP, '1000000000000000000')).toString()) / (BigInt(2)**BigInt(112)) / (BigInt(10)**BigInt(18));
    console.log('usdt lp price', price2)
    //////// end of oracles ////////////////////////////////////////////


    //////// collaterals ////////////////////////////////////////////
    const vaultManagerParameters = await attachContract('VaultManagerParameters', VAULT_MANAGER_PARAMETERS);

    await vaultManagerParameters.connect(multisig).setCollateral(//tx
        wrappedSlpUsdt.address,
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

    // WARNING not for prod!! for testing of liquidations
    await vaultManagerParameters.connect(multisig).setInitialCollateralRatio(wrappedSlpUsdt.address, 100);
    //////// end of collaterals ////////////////////////////////////////////


    //////// auction ////////////////////////////////////////////
    const parameters = await attachContract(
        'AssetsBooleanParameters',
        "0xcc33c2840b65c0a4ac4015c650dd20dc3eb2081d"
    );
    await parameters.connect(multisig).set('0x4bfB2FA13097E5312B19585042FdbF3562dC8676', PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, true);
    await parameters.connect(multisig).set('0x988AAf8B36173Af7Ad3FEB36EfEc0988Fbd06d07', PARAM_FORCE_TRANSFER_ASSET_TO_OWNER_ON_LIQUIDATION, true);

    await parameters.connect(multisig).set(wrappedSlpUsdt.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);

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
    

    //////// wsslp simple case ////////////////////////////////////////////
    // const sushi = await attachContract('IERC20', REWARD_TOKEN)
    //
    // console.log('-- check wslp')
    // const balance = (await slpUsdt.balanceOf(TEST_WALLET)).toString();
    // console.log("balance of usdt sslp: ", balance)
    // console.log("balance of sushi: ", (await sushi.balanceOf(TEST_WALLET)).toString())
    //
    // await slpUsdt.connect(testWallet).approve(wrappedSlpUsdt.address, '1000000000000000000000');
    // await wrappedSlpUsdt.connect(testWallet).approve(VAULT, '1000000000000000000000');
    // await usdp.connect(testWallet).approve(cdpManager.address, '1000000000000000000000');
    //
    // await cdpManager.connect(testWallet).wrapAndJoin(wrappedSlpUsdt.address, balance, '50000000000000000000');
    //
    // console.log('claimable sushi: ', (await wrappedSlpUsdt.pendingReward(testWallet.address)).toString())
    // await network.provider.send("evm_mine");
    // await network.provider.send("evm_mine");
    // console.log('claimable sushi after 2 blocks: ', (await wrappedSlpUsdt.pendingReward(testWallet.address)).toString())
    // console.log('bones fees wallet balance before claim: ', (await sushi.balanceOf(MULTISIG_FEE)).toString())
    // await wrappedSlpUsdt.connect(testWallet).claimReward(testWallet.address)
    // console.log("balance of sushi: ", (await sushi.balanceOf(TEST_WALLET)).toString())
    // console.log('sushi fees wallet balance after claim: ', (await sushi.balanceOf(MULTISIG_FEE)).toString())
    //////// end of wsslp simple case ////////////////////////////////////////////

    //////// wrapped asset leverage ////////////////////////////////////////////
    // console.log('-- check simple leverage')
    // const assetAmount = await slpUsdt.balanceOf(TEST_WALLET);
    // const usdpAmount = ether('250'); // leverage >2 atm
    //
    // const wslpBalance1 = await wrappedSlpUsdt.balanceOf(TEST_WALLET);
    // const slpBalance1 = await slpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance1 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition1 = await vault.collaterals(wrappedSlpUsdt.address, TEST_WALLET);
    // const debt1 = await vault.debts(wrappedSlpUsdt.address, TEST_WALLET);
    // console.log(`balances before: slp ${weiToEther(slpBalance1)}, wslp ${weiToEther(wslpBalance1)}, usdp ${weiToEther(usdpBalance1)}`);
    // console.log(`position before: ${weiToEther(vaultPosition1)}, debt: ${weiToEther(debt1)}`);
    //
    // await slpUsdt.connect(testWallet).approve(wrappedSlpUsdt.address, ether('5000')); // wrap
    // await usdp.connect(testWallet).approve(cdpManager.address, ether('5000')); // borrow fee
    // await wrappedSlpUsdt.connect(testWallet).approve(VAULT, ether('5000')); // borrow
    // await usdp.connect(testWallet).approve(swapperLp.address, ether('5000')); // swap
    // await slpUsdt.connect(testWallet).approve(swapperLp.address, ether('5000')); // swap back
    //
    // const predictedWeth = await swapperLp.predictAssetOut(slpUsdt.address, usdpAmount);
    // await cdpManager.connect(testWallet).wrapAndJoinWithLeverage(wrappedSlpUsdt.address, swapperLp.address, assetAmount, usdpAmount, predictedWeth.mul(99).div(100));
    //
    // const wslpBalance2 = await wrappedSlpUsdt.balanceOf(TEST_WALLET);
    // const slpBalance2 = await slpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance2 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition2 = await vault.collaterals(wrappedSlpUsdt.address, TEST_WALLET);
    // const debt2 = await vault.debts(wrappedSlpUsdt.address, TEST_WALLET);
    // console.log(`balances after: slp ${weiToEther(slpBalance2)}, wslp ${weiToEther(wslpBalance2)}, usdp ${weiToEther(usdpBalance2)}`);
    // console.log(`position after: ${weiToEther(vaultPosition2)}, debt: ${weiToEther(debt2)}, diff: ${weiToEther(vaultPosition2.sub(vaultPosition1))}`);
    //
    // assert(slpBalance1.sub(assetAmount).eq(slpBalance2))
    // assert(wslpBalance2.eq(wslpBalance1));
    // assert(usdpBalance1.eq(usdpBalance2));
    // assert(vaultPosition2.sub(vaultPosition1).gt(assetAmount));
    //
    // console.log('-- deleverage')
    // const predictedUsdp = await swapperLp.predictUsdpOut(slpUsdt.address, assetAmount.div(2));
    // await cdpManager.connect(testWallet).unwrapAndExitWithDeleverage(wrappedSlpUsdt.address, swapperLp.address, assetAmount.div(2), assetAmount.div(2), predictedUsdp.mul(99).div(100));
    //
    // const wslpBalance3 = await wrappedSlpUsdt.balanceOf(TEST_WALLET);
    // const slpBalance3 = await slpUsdt.balanceOf(TEST_WALLET);
    // const usdpBalance3 = await usdp.balanceOf(TEST_WALLET);
    // const vaultPosition3 = await vault.collaterals(wrappedSlpUsdt.address, TEST_WALLET);
    // const debt3 = await vault.debts(wrappedSlpUsdt.address, TEST_WALLET);
    // console.log(`balances after: slp ${weiToEther(slpBalance3)}, wslp ${weiToEther(wslpBalance3)}, usdp ${weiToEther(usdpBalance3)}`);
    // console.log(`position after: ${weiToEther(vaultPosition3)}, debt: ${weiToEther(debt3)}`);
    //
    //
    // assert(slpBalance3.sub(slpBalance2).eq(assetAmount.div(2)));
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

