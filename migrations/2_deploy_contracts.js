const Vault = artifacts.require('Vault');
const Parameters = artifacts.require('Parameters');
const USDP = artifacts.require('USDP');
const WETH = artifacts.require('WETH');
const DummyToken = artifacts.require('DummyToken');
const UniswapOracle = artifacts.require('UniswapOracle');
const IUniswapV2Factory = artifacts.require('IUniswapV2Factory');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const VaultManager = artifacts.require('VaultManager');
const Liquidator = artifacts.require('Liquidator');
const { ether } = require('openzeppelin-test-helpers');
const { calculateAddressAtNonce } = require('../test/helpers/deployUtils');
const BN = web3.utils.BN;

const getUtils = context => {
  return {
    poolDeposit: async (token, amount, decimals) => {
      amount = decimals ? new BN(String(amount * 10 ** decimals)) : ether(amount.toString());
      amount = amount.div(new BN((10 ** 6).toString()));

      const block = await web3.eth.getBlock('latest');
      const time = new BN(block.timestamp);

      await token.approve(context.uniswapRouter.address, amount);
      await context.uniswapRouter.addLiquidity(
        token.address,
        context.weth.address,
        amount,
        ether('1').div(new BN((10 ** 6).toString())),
        amount,
        ether('1').div(new BN((10 ** 6).toString())),
        context.deployer,
        time.add(new BN('10000')),
      );
    },
  }
};

module.exports = async function(deployer, network) {
  const utils = getUtils(this);

  if (network !== 'ropsten-fork') {
    console.log(`Contracts will not be deployed on this network: ${network}`);
    return;
  }

  await deployer;

  this.deployer = deployer.networks[network].from;

  const col = await deployer.deploy(DummyToken, "COL testnet", "COL", 18, ether('1000000'));
  const dai = await deployer.deploy(DummyToken, "DAI testnet", "DAI", 18, ether('1000000'));
  const usdc = await deployer.deploy(DummyToken, "USDC testnet", "USDC", 6, String(10000000 * 10 ** 6));
  this.weth = await WETH.at('0xd0A1E359811322d97991E03f863a0C30C2cF029C');
  // this.weth = await WETH.at('0x348E004B789D5C6BBC65cEaaDE84f7Fad897EBB8');
  const someCollateral = await deployer.deploy(DummyToken, "Example collateral token", "ECT", 18, ether('1000000'));

  await this.weth.deposit({ value: ether('1') });

  const uniswapFactory = await IUniswapV2Factory.at('0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f');
  // const uniswapFactory = await IUniswapV2Factory.at('0xbcFBC1DF1e886B8835098EFD8971fDf89F9aeFF1');
  await uniswapFactory.createPair(dai.address, this.weth.address);
  await uniswapFactory.createPair(usdc.address, this.weth.address);

  const uniswapOracle = await deployer.deploy(UniswapOracle,
    uniswapFactory.address,
    dai.address,
    usdc.address,
    this.weth.address,
  );

  const parametersAddr = calculateAddressAtNonce(this.deployer, await web3.eth.getTransactionCount(this.deployer) + 1, web3);
  const usdp = await deployer.deploy(USDP, parametersAddr);
  const vaultAddr = calculateAddressAtNonce(this.deployer, await web3.eth.getTransactionCount(this.deployer) + 1, web3);
  const parameters = await deployer.deploy(Parameters, vaultAddr);
  const vault = await deployer.deploy(Vault, parameters.address, col.address, usdp.address);
  const liquidator = await deployer.deploy(Liquidator, parameters.address, vault.address, uniswapOracle.address, col.address, this.deployer);
  const vaultManager = await deployer.deploy(VaultManager,
    vault.address,
    liquidator.address,
    parameters.address,
    uniswapOracle.address,
    col.address
  );

  this.uniswapRouter = await UniswapV2Router02.at('0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D');
  // this.uniswapRouter = await UniswapV2Router02.at('0x5695C483B22bd5018416B5A5118236306d438C85');

  await this.weth.approve(this.uniswapRouter.address, ether('100'));

  // Add liquidity to DAI/WETH pool; rate = 200 DAI/ETH
  await utils.poolDeposit(dai, 200);

  // Add liquidity to USDC/WETH pool
  await utils.poolDeposit(usdc, 300, 6);

  // Add liquidity to COL/WETH pool; rate = 250 COL/WETH; 1 COL = 1 USD
  await utils.poolDeposit(col, 250);

  // Add liquidity to some token/WETH pool; rate = 125 token/WETH; 1 token = 2 USD
  await utils.poolDeposit(someCollateral, 125);

  await parameters.setOracleType('1', true);
  await parameters.setVaultAccess(vaultManager.address, true);
  await parameters.setCollateral(
    someCollateral.address,
    '0', // stability fee
    '100', // liquidation fee
    '150', // min collateralization
    ether('100000'), // debt limit
  );
};
