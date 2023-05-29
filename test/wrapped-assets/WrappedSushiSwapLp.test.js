const {expect} = require("chai");
const {ethers} = require("hardhat");
const {
    prepareWrappedSLP, CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN,
    CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX,
} = require("../helpers/deploy");
const {deployContract, attachContract, ether, BN} = require("../helpers/ethersUtils");
const {PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION} = require("../../lib/constants");
const {cdpManagerWrapper} = require("../helpers/cdpManagerWrappers");
const {ZERO_ADDRESS} = require("../helpers/deployUtils");
const Abi = require('@ethersproject/abi');
const {sushiReward} = require("./helpers/MasterChefLogic");

const EPSILON = BN('400000');

const oracleCases = [
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN, 'cdp manager'],
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN_KEYDONIX, 'cdp manager keydonix'],
]

let context = {};
describe("WrappedSushiSwapLp", function () {

    beforeEach(async function () {
        await network.provider.send("evm_setAutomine", [true]);

        [context.deployer, context.user1, context.user2, context.user3, context.manager, context.sushiFeeReceiver] = await ethers.getSigners();
    });

    describe("factory", function () {
        beforeEach(async function () {
            await prepareWrappedSLP(context, CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN);
        })

        it('set fee for manager only', async function () {
            await context.wslpFactory.setFee('0x0000000000000000000000000000000000000005', 10);

            await expect(
              context.wslpFactory.connect(context.user3).setFee('0x0000000000000000000000000000000000000006', 11)
            ).to.be.revertedWith("AUTH_FAILED");

            expect(await context.wslpFactory.feeInfo()).deep.to.be.equal(['0x0000000000000000000000000000000000000005', 10]);
        })

        it('fee in range', async function () {
            await context.wslpFactory.setFee('0x0000000000000000000000000000000000000000', 50);
            await context.wslpFactory.setFee('0x0000000000000000000000000000000000000050', 0);

            await expect(
              context.wslpFactory.setFee('0x0000000000000000000000000000000000000000', 51)
            ).to.be.revertedWith("INVALID_FEE");

            expect(await context.wslpFactory.feeInfo()).deep.to.be.equal(['0x0000000000000000000000000000000000000050', 0]);
        })
    });

    describe("Oracles independent tests", function () {
        beforeEach(async function () {
            await prepareWrappedSLP(context, CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN);

            // initials distribution of lptokens to users
            await context.lpToken0.transfer(context.user1.address, ether('1'));
            await context.lpToken0.transfer(context.user2.address, ether('1'));
            await context.lpToken0.transfer(context.user3.address, ether('1'));
        })

        describe("constructor", function () {
            it("wrapped token name and symbol", async function () {
                expect(await context.wrappedSlp0.symbol()).to.be.equal("wuSSLP0tokenAtokenB"); // pool 0 with lpToken0 (tokenA, tokenB)
                expect(await context.wrappedSlp0.name()).to.be.equal("Wrapped by Unit SushiSwap LP0 tokenA-tokenB"); // pool 1 with lpToken1 (tokenC, tokenD)
                expect(await context.wrappedSlp0.decimals()).to.be.equal(await context.lpToken0.decimals());

                expect(await context.wrappedSlp1.symbol()).to.be.equal("wuSSLP1tokenCtokenD"); // pool 1 with lpToken1 (tokenC, tokenD)
                expect(await context.wrappedSlp1.name()).to.be.equal("Wrapped by Unit SushiSwap LP1 tokenC-tokenD"); // pool 1 with lpToken1 (tokenC, tokenD)
                expect(await context.wrappedSlp1.decimals()).to.be.equal(await context.lpToken1.decimals());
            });

            it("reinitialization is prohibited", async function () {
                await expect(
                  context.wrappedSlp0.initialize(1)
                ).to.be.revertedWith("Initializable: contract is already initialized");
            });
        });

        describe("pool direct deposit/withdraw", function () {
            it("prohibited deposit for another user", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await expect(
                    context.wrappedSlp0.connect(context.user1).deposit(context.user2.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");
            });

            it("not approved lp token", async function () {
                const lockAmount = ether('0.4');
                await expect(
                    context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount)
                ).to.be.revertedWith("TRANSFER_FROM_FAILED");
            });

            it("zero deposit", async function () {
                await expect(
                    context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, 0)
                ).to.be.revertedWith("INVALID_AMOUNT");
            });

            it("reinitialization", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const user1ProxyAddr = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user1Proxy = await attachContract('WSLPUserProxy', user1ProxyAddr);

                // user cannot transfer tokens
                await expect(
                    user1Proxy.initialize(1, context.user3.address)
                ).to.be.revertedWith("ALREADY_INITIALIZED");
            });

            it("transfer lp token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));
                await prepareUserForJoin(context.user2, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                await context.wrappedSlp0.connect(context.user2).deposit(context.user2.address, lockAmount);

                // user cannot transfer tokens
                await expect(
                    context.wrappedSlp0.connect(context.user1).transfer(context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // another user cannot transfer tokens
                await expect(
                    context.wrappedSlp0.connect(context.user2).transfer(context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");
            });


            it("transfer from for lp token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);

                // user cannot transfer tokens from another
                await expect(
                    context.wrappedSlp0.connect(context.user2).transferFrom(context.user1.address, context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // even if they are approved
                await context.usdp.connect(context.user1).approve(context.user2.address, lockAmount);
                await expect(
                    context.wrappedSlp0.connect(context.user2).transferFrom(context.user1.address, context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // transfer allowance for vault tested in liquidation cases
            });

            it("simple deposit/withdraw", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);


                await context.wrappedSlp0.connect(context.user1).withdraw(context.user1.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

                expect(await rewardTokenBalance(context.user1)).to.be.equal(0);
                await claimReward(context.user1)
                expect(await rewardTokenBalance(context.user1)).not.to.be.equal(0);
            });

            it("separate state in pools", async function () {
                const lockAmount = ether('0.4');

                await context.lpToken1.transfer(context.user1.address, ether('1'));

                await context.lpToken0.connect(context.user1).approve(context.wrappedSlp0.address, lockAmount);
                await context.lpToken1.connect(context.user1).approve(context.wrappedSlp1.address, lockAmount);

                const {blockNumber: deposit1Block} = await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                const {blockNumber: deposit2Block} = await context.wrappedSlp1.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.lpToken1.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp1.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                const user1ProxyAddr = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user1Proxy = await attachContract('WSLPUserProxy', user1ProxyAddr);

                const user1ProxyAddr2 = await context.wrappedSlp1.usersProxies(context.user1.address);
                const user1Proxy2 = await attachContract('WSLPUserProxy', user1ProxyAddr2);

                const {blockNumber: withdraw2Block} = await context.wrappedSlp1.connect(context.user1).withdraw(context.user1.address, lockAmount);
                expect(await context.lpToken1.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp1.balanceOf(context.user1.address)).to.be.equal(0);

                const {blockNumber: withdraw1Block} = await context.wrappedSlp0.connect(context.user1).withdraw(context.user1.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

                const user1Reward1 = sushiReward(deposit1Block, withdraw1Block);
                expect(await rewardTokenBalance(user1Proxy)).to.be.closeTo(user1Reward1, EPSILON);

                const user1Reward2 = sushiReward(deposit2Block, withdraw2Block);
                expect(await rewardTokenBalance(user1Proxy2)).to.be.closeTo(user1Reward2, EPSILON);

                await claimReward(context.user1)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward1, EPSILON);

                await context.wrappedSlp1.connect(context.user1).claimReward(context.user1.address);
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward1.add(user1Reward2), EPSILON);
            });

            it("emergency withdraw + withdraw any token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                await context.wrappedSlp0.connect(context.user1).emergencyWithdraw();
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.lpToken0.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

                expect(await rewardTokenBalance(context.user1)).to.be.equal(0);
                await claimReward(context.user1)
                expect(await rewardTokenBalance(context.user1)).to.be.equal(0);
            });

            it("withdraw reward token from proxy (with fee)", async function () {
                await context.wslpFactory.setFee(context.sushiFeeReceiver.address, 10);

                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const user1ProxyAddr = await context.wrappedSlp0.usersProxies(context.user1.address);

                // part of reward token balances
                const proxyRewardTokenBalance1 = await rewardTokenBalance(user1ProxyAddr);
                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.rewardToken.address, proxyRewardTokenBalance1.div(2));
                const proxyRewardTokenBalance2 = await rewardTokenBalance(user1ProxyAddr);
                const userRewardTokenBalance2 = await rewardTokenBalance(context.user1);
                const feeReceiverRewardTokenBalance2 = await rewardTokenBalance(context.sushiFeeReceiver);

                expect(proxyRewardTokenBalance2).to.be.equal(proxyRewardTokenBalance1.div(2));
                expect(userRewardTokenBalance2).to.be.equal(proxyRewardTokenBalance1.div(2).mul(90).div(100));
                expect(feeReceiverRewardTokenBalance2).to.be.equal(proxyRewardTokenBalance1.div(2).mul(10).div(100));

                // all
                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.rewardToken.address, proxyRewardTokenBalance2);
                const proxyRewardTokenBalance3 = await rewardTokenBalance(user1ProxyAddr);
                const userRewardTokenBalance3 = await rewardTokenBalance(context.user1);
                const feeReceiverRewardTokenBalance3 = await rewardTokenBalance(context.sushiFeeReceiver);

                expect(proxyRewardTokenBalance3).to.be.equal(0);
                expect(userRewardTokenBalance3).to.be.equal(proxyRewardTokenBalance1.mul(90).div(100));
                expect(feeReceiverRewardTokenBalance3).to.be.equal(proxyRewardTokenBalance1.mul(10).div(100));
            });

            it("withdraw some token from proxy (with fee)", async function () {
                await context.wslpFactory.setFee(context.sushiFeeReceiver.address, 10);

                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const user1ProxyAddr = await context.wrappedSlp0.usersProxies(context.user1.address);

                const amount = ether('1');
                await context.lpToken1.transfer(user1ProxyAddr, amount);

                // part of balances
                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.lpToken1.address, amount.div(2));
                const proxyBalance2 = await context.lpToken1.balanceOf(user1ProxyAddr);
                const userBalance2 = await context.lpToken1.balanceOf(context.user1.address);
                const feeReceiverBalance2 = await context.lpToken1.balanceOf(context.sushiFeeReceiver.address);

                expect(proxyBalance2).to.be.equal(amount.div(2));
                expect(userBalance2).to.be.equal(amount.div(2));
                expect(feeReceiverBalance2).to.be.equal(0);

                // all
                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.lpToken1.address, amount.div(2));
                const proxyBalance3 = await context.lpToken1.balanceOf(user1ProxyAddr);
                const userBalance3 = await context.lpToken1.balanceOf(context.user1.address);
                const feeReceiverBalance3 = await context.lpToken1.balanceOf(context.sushiFeeReceiver.address);

                expect(proxyBalance3).to.be.equal(0);
                expect(userBalance3).to.be.equal(amount);
                expect(feeReceiverBalance3).to.be.equal(0);
            });

            it("no emergency withdrawal allowed with unit position", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await wrapAndJoin(context.user1, lockAmount, 0);

                await expect(
                    context.wrappedSlp0.connect(context.user1).emergencyWithdraw()
                ).to.be.revertedWith("burn amount exceeds balance");

                await cdpManagerWrapper.exit(context, context.user1, context.wrappedSlp0, lockAmount.div(2), 0);

                await expect(
                    context.wrappedSlp0.connect(context.user1).emergencyWithdraw()
                ).to.be.revertedWith("burn amount exceeds balance");

                // full exit from unit, user got all wrapped tokens
                await cdpManagerWrapper.exit(context, context.user1, context.wrappedSlp0, lockAmount.div(2), 0);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'));

                await context.wrappedSlp0.connect(context.user1).emergencyWithdraw()
                await context.wrappedSlp0.connect(context.user1).withdrawToken(context.lpToken0.address, lockAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

            });
        });

        describe("proxies direct calls", function () {
            it("only manager methods", async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, lockAmount);
                await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const user1ProxyAddr = await context.wrappedSlp0.usersProxies(context.user1.address);
                expect(user1ProxyAddr).not.to.be.equal(ZERO_ADDRESS);

                const user1Proxy = await attachContract('WSLPUserProxy', user1ProxyAddr);

                await expect(
                    user1Proxy.approveLpToRewardDistributor(context.lpToken0.address)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.deposit(ether('1'))
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.withdraw(context.lpToken0.address, ether('1'), context.user1.address)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.claimReward(context.user1.address)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.emergencyWithdraw()
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.withdrawToken(context.lpToken0.address, context.user1.address, 100)
                ).to.be.revertedWith("AUTH_FAILED");
            });
        });

        describe("reward distribution cases", function () {
            it('consecutive deposit and withdrawal with 3 users', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);
                await prepareUserForJoin(context.user3, lockAmount);

                const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
                const {blockNumber: deposit2Block} = await wrapAndJoin(context.user2, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'), "transferred from user");
                const {blockNumber: deposit3Block} = await wrapAndJoin(context.user3, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user3.address)).to.be.equal(ether('0.6'), "transferred from user");

                expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount.mul(3), "transferred to reward distributor");
                expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(lockAmount.mul(3), "wrapped token sent to vault");
                expect(await context.wrappedSlp0.totalSupply()).to.be.equal(lockAmount.mul(3), "minted only wrapped tokens for deposited amount");

                const {blockNumber: withdrawal1Block} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");
                const {blockNumber: withdrawal2Block} = await unwrapAndExit(context.user2, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");
                const {blockNumber: withdrawal3Block} = await unwrapAndExit(context.user3, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");

                const user1Proxy = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSlp0.usersProxies(context.user2.address);
                const user3Proxy = await context.wrappedSlp0.usersProxies(context.user3.address);

                // no reward sent to user on deposit/withdrawal
                expect(await rewardTokenBalance(context.user1)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user2)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                // but reward was sent to user proxies by reward distributor
                // with 3 simultaneous users we have imprecise calculations
                const user1Reward = sushiReward(deposit1Block, deposit2Block)
                    .add(sushiReward(deposit2Block, deposit3Block).div(2))
                    .add(sushiReward(deposit3Block, withdrawal1Block).div(3));
                expect(await rewardTokenBalance(user1Proxy)).to.be.closeTo(user1Reward, EPSILON);

                const user2Reward = sushiReward(deposit2Block, deposit3Block).div(2)
                    .add(sushiReward(deposit3Block, withdrawal1Block).div(3))
                    .add(sushiReward(withdrawal1Block, withdrawal2Block).div(2));
                expect(await rewardTokenBalance(user2Proxy)).to.be.closeTo(user2Reward, EPSILON);

                const user3Reward = sushiReward(deposit3Block, withdrawal1Block).div(3)
                    .add(sushiReward(withdrawal1Block, withdrawal2Block).div(2))
                    .add(sushiReward(withdrawal2Block, withdrawal3Block).div(1));
                expect(await rewardTokenBalance(user3Proxy)).to.be.closeTo(user3Reward, EPSILON);

                await claimReward(context.user1)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user2)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user3)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await rewardTokenBalance(context.user3)).to.be.closeTo(user3Reward, EPSILON);

                expect(await rewardTokenBalance(user1Proxy)).to.be.equal(0);
                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(0);
                expect(await rewardTokenBalance(user3Proxy)).to.be.equal(0);
            })

            it('reward tokens distribution with non consecutive deposit and withdrawal with 3 users', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);
                await prepareUserForJoin(context.user3, lockAmount);

                const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const {blockNumber: deposit2Block} = await wrapAndJoin(context.user2, lockAmount, usdpAmount);

                const {blockNumber: withdrawal1Block} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                const {blockNumber: deposit3Block} = await wrapAndJoin(context.user3, lockAmount, usdpAmount);

                const {blockNumber: withdrawal2Block} = await unwrapAndExit(context.user2, lockAmount, usdpAmount);
                const {blockNumber: withdrawal3Block} = await unwrapAndExit(context.user3, lockAmount, usdpAmount);

                const user1Proxy = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSlp0.usersProxies(context.user2.address);
                const user3Proxy = await context.wrappedSlp0.usersProxies(context.user3.address);

                // no reward sent to user on deposit/withdrawal
                expect(await rewardTokenBalance(context.user1)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user2)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                const user1Reward = sushiReward(deposit1Block, deposit2Block)
                    .add(sushiReward(deposit2Block, withdrawal1Block).div(2));
                expect(await rewardTokenBalance(user1Proxy)).to.be.equal(user1Reward);

                const user2Reward = sushiReward(deposit2Block, withdrawal1Block).div(2)
                    .add(sushiReward(withdrawal1Block, deposit3Block))
                    .add(sushiReward(deposit3Block, withdrawal2Block).div(2));
                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(user2Reward);

                const user3Reward = sushiReward(deposit3Block, withdrawal2Block).div(2)
                    .add(sushiReward(withdrawal2Block, withdrawal3Block));
                expect(await rewardTokenBalance(user3Proxy)).to.be.equal(user3Reward);

                await claimReward(context.user1)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user2)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await rewardTokenBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user3)
                expect(await rewardTokenBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await rewardTokenBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await rewardTokenBalance(context.user3)).to.be.closeTo(user3Reward, EPSILON);

                expect(await rewardTokenBalance(user1Proxy)).to.be.equal(0);
                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(0);
                expect(await rewardTokenBalance(user3Proxy)).to.be.equal(0);
            })

            it('simple case for pending reward', async function () {
                const lockAmount = ether('0.2');
                const usdpAmount = ether('50');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                await network.provider.send("evm_mine");
                const block2 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block2));

                await network.provider.send("evm_mine");
                const block3 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block3));

                const {blockNumber: block4} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block4));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user1)).to.be.equal(sushiReward(block1, block4));
            })

            it('reward tokens fee', async function () {
                await context.wslpFactory.setFee(context.sushiFeeReceiver.address, 10);

                const lockAmount = ether('0.2');
                const usdpAmount = ether('50');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                await network.provider.send("evm_mine");
                const block2 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block2).mul(90).div(100));

                await network.provider.send("evm_mine");
                const block3 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block3).mul(90).div(100));

                const {blockNumber: block4} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block4).mul(90).div(100));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user1)).to.be.equal(sushiReward(block1, block4).mul(90).div(100));
                expect(await rewardTokenBalance(context.sushiFeeReceiver)).to.be.equal(sushiReward(block1, block4).mul(10).div(100));
            })

            it('reward tokens fee with empty receiver', async function () {
                await context.wslpFactory.setFee(ZERO_ADDRESS, 10);

                const lockAmount = ether('0.2');
                const usdpAmount = ether('50');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                const {blockNumber: block2} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(sushiReward(block1, block2));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await rewardTokenBalance(context.user1)).to.be.equal(sushiReward(block1, block2));
                expect(await rewardTokenBalance(context.sushiFeeReceiver)).to.be.equal(0);
            })

        });

        describe("reward distributor edge cases", function () {
            it('handle change of lptopken in reward distributor', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, ether('1'));

                context.migratorChef = await deployContract("MigratorChef_Mock");
                await context.migratorChef.setNewToken(context.lpToken1.address);
                await context.lpToken1.transfer(context.migratorChef.address, ether('100'));
                await context.rewardDistributor.setMigrator(context.migratorChef.address);

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
                expect(await context.lpToken1.balanceOf(context.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
                expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount, "old lp tokens sent to reward distributor");
                expect(await context.lpToken1.balanceOf(context.rewardDistributor.address)).to.be.equal(ether('0'), "no reward distributor balance in new lp token");

                expect(await context.wrappedSlp0.getUnderlyingToken()).to.be.equal(context.lpToken0.address);
                await context.rewardDistributor.connect(context.user3).migrate(0); // anyone can migrate
                expect(await context.wrappedSlp0.getUnderlyingToken()).to.be.equal(context.lpToken1.address);

                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
                expect(await context.lpToken1.balanceOf(context.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
                expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount, "old lp tokens sent to reward distributor");
                expect(await context.lpToken1.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount, "reward distributor balance in new lp tokens");

                await unwrapAndExit(context.user1, lockAmount, usdpAmount);

                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in old lp tokens");
                expect(await context.lpToken1.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new lp tokens");
                expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount, "old lp tokens didn't use");
                expect(await context.lpToken1.balanceOf(context.rewardDistributor.address)).to.be.equal(ether('0'), "no new lp tokens left in reward distributor");

                // reapprove new lp to pool
                await context.lpToken1.connect(context.user1).approve(context.wrappedSlp0.address, ether('1'));
                // revert since new lp is not approved for reward distributor
                await expect(
                  wrapAndJoin(context.user1, lockAmount, usdpAmount)
                ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");

                await context.wrappedSlp0.connect(context.user1).approveLpToRewardDistributor();
                await wrapAndJoin(context.user1, lockAmount, usdpAmount); // success
            })
        });

        describe("liquidations related", function () {
            it('move position', async function () {
                const lockAmount = ether('0.4');

                await prepareUserForJoin(context.user1, lockAmount);

                await context.vaultParameters.connect(context.deployer).setVaultAccess(context.deployer.address, true);

                const {blockNumber: block1} = await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const {blockNumber: block2} = await context.wrappedSlp0.connect(context.deployer).movePosition(context.user1.address, context.user2.address, ether('0.1'));

                const user1Proxy = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSlp0.usersProxies(context.user2.address);
                expect(user2Proxy).not.to.be.equal(ZERO_ADDRESS); // created on movePosition

                expect(await rewardTokenBalance(user1Proxy)).to.be.equal(sushiReward(block1, block2)); // sent to proxy
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'), 'no wrapped tokens transferred');

                expect(await rewardTokenBalance(context.user2)).to.be.equal(0);
                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user2.address)).to.be.equal(0, 'no wrapped tokens transferred');

                // next movePosition is senselessly since contract is in inconsistent state
            })

            it('move position to the same user', async function () {
                const lockAmount = ether('0.4');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);

                await context.vaultParameters.connect(context.deployer).setVaultAccess(context.deployer.address, true);

                const {blockNumber: block1} = await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, ether('0.1'));
                const {blockNumber: block2} = await context.wrappedSlp0.connect(context.user2).deposit(context.user2.address, lockAmount);
                const {blockNumber: block3} = await context.wrappedSlp0.connect(context.deployer).movePosition(context.user2.address, context.user2.address, ether('0.2'));

                const user1Proxy = await context.wrappedSlp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSlp0.usersProxies(context.user2.address);

                expect(await rewardTokenBalance(user1Proxy)).to.be.equal(0);
                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(0);

                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user2.address)).to.be.equal(lockAmount, 'no wrapped tokens transferred');

                const {blockNumber: block4} = await context.wrappedSlp0.connect(context.deployer).movePosition(context.user2.address, context.user2.address, lockAmount);
                // nothing changes
                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(0);
                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSlp0.balanceOf(context.user2.address)).to.be.equal(lockAmount, 'no wrapped tokens transferred');

                const {blockNumber: block5} = await context.wrappedSlp0.connect(context.user2).withdraw(context.user2.address, lockAmount); // can withdraw

                expect(await rewardTokenBalance(user2Proxy)).to.be.equal(sushiReward(block2, block5).mul(4).div(5))
                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSlp0.balanceOf(context.user2.address)).to.be.equal(0, 'wrapped tokens burned');
            })

            it('liquidation (with moving position)', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, lockAmount);
                await context.assetsBooleanParameters.set(context.wrappedSlp0.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);
                await context.usdp.tests_mint(context.user2.address, usdpAmount.mul(2));
                await context.usdp.connect(context.user2).approve(context.vault.address, usdpAmount.mul(2));

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);

                await context.vaultManagerParameters.setInitialCollateralRatio(context.wrappedSlp0.address, BN(9));
                await context.vaultManagerParameters.setLiquidationRatio(context.wrappedSlp0.address, BN(10));


                await cdpManagerWrapper.triggerLiquidation(context, context.wrappedSlp0, context.user1);

                expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped tokens in vault");
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.wrappedSlp0.balanceOf(context.user2.address)).to.be.equal(0);

                await mineBlocks(10)

                await context.liquidationAuction.connect(context.user2).buyout(context.wrappedSlp0.address, context.user1.address);

                expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped tokens not in vault");
                let ownerCollateralAmount = await context.wrappedSlp0.balanceOf(context.user1.address);
                let liquidatorCollateralAmount = await context.wrappedSlp0.balanceOf(context.user2.address);
                expect(lockAmount).to.be.equal(ownerCollateralAmount.add(liquidatorCollateralAmount))

                await context.wrappedSlp0.connect(context.user1).withdraw(context.user1.address, ownerCollateralAmount);
                await context.wrappedSlp0.connect(context.user2).withdraw(context.user2.address, liquidatorCollateralAmount);

                expect(await context.wrappedSlp0.totalSupply()).to.be.equal(0);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ownerCollateralAmount.add(ether('0.6')), 'withdrawn all tokens');
                expect(await context.lpToken0.balanceOf(context.user2.address)).to.be.equal(liquidatorCollateralAmount.add(ether('1')), 'withdrawn all tokens');
            })

            it('liquidation by owner (with moving position)', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('100');

                await prepareUserForJoin(context.user1, lockAmount);
                await context.assetsBooleanParameters.set(context.wrappedSlp0.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);
                await context.usdp.connect(context.user1).approve(context.vault.address, usdpAmount.mul(2));

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);

                await context.vaultManagerParameters.setInitialCollateralRatio(context.wrappedSlp0.address, BN(9));
                await context.vaultManagerParameters.setLiquidationRatio(context.wrappedSlp0.address, BN(10));

                await cdpManagerWrapper.triggerLiquidation(context, context.wrappedSlp0, context.user1);

                expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped tokens in vault");
                expect(await context.vault.collaterals(context.wrappedSlp0.address, context.user1.address)).to.be.equal(lockAmount);
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0);

                await mineBlocks(52);

                await context.liquidationAuction.connect(context.user1).buyout(context.wrappedSlp0.address, context.user1.address);

                expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped tokens not in vault");
                expect(await context.vault.collaterals(context.wrappedSlp0.address, context.user1.address)).to.be.equal(0);
                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, 'tokens = position');

                await context.wrappedSlp0.connect(context.user1).withdraw(context.user1.address, lockAmount);

                expect(await context.wrappedSlp0.totalSupply()).to.be.equal(0);
                expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), 'withdrawn all tokens');

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.not.equal(ether('0'), 'user1 with collateral and usdp :pokerface:');
            })
        });
    })

    oracleCases.forEach(params => {
        describe(`Oracles dependent tests with ${params[1]}`, function () {
            beforeEach(async function () {
                await prepareWrappedSLP(context, params[0]);

                // initials distribution of lptokens to users
                await context.lpToken0.transfer(context.user1.address, ether('1'));
                await context.lpToken0.transfer(context.user2.address, ether('1'));
                await context.lpToken0.transfer(context.user3.address, ether('1'));
            })

            describe("join/exit cases via cdp manager", function () {
                [1, 10].forEach(blockInterval =>
                    it(`simple deposit and withdrawal with interval ${blockInterval} blocks`, async function () {
                        const lockAmount = ether('0.4');
                        const usdpAmount = ether('100');

                        await prepareUserForJoin(context.user1, lockAmount);

                        const {blockNumber: depositBlock} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                        expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
                        expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");
                        expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(lockAmount, "transferred to reward distributor");
                        expect(await context.lpToken0.balanceOf(context.wrappedSlp0.address)).to.be.equal(ether('0'), "transferred not to pool");
                        expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped token sent to vault");
                        expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0, "wrapped token sent not to user");
                        expect(await context.wrappedSlp0.totalSupply()).to.be.equal(lockAmount, "minted only wrapped tokens for deposited amount");

                        for (let i = 0; i < blockInterval - 1; ++i) {
                            await network.provider.send("evm_mine");
                        }

                        const {blockNumber: withdrawalBlock} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                        expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                        expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0, "returned usdp");
                        expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(0, "everything were withdrawn from reward distributor");
                        expect(await context.lpToken0.balanceOf(context.wrappedSlp0.address)).to.be.equal(ether('0'), "withdrawn not to pool");
                        expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                        expect(await context.wrappedSlp0.totalSupply()).to.be.equal(0, "everything were burned");

                        await claimReward(context.user1);
                        expect(await rewardTokenBalance(context.user1)).to.be.equal(sushiReward(depositBlock, withdrawalBlock), "reward tokens reward got");
                    })
                );

                it(`simple deposit in one block`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, lockAmount);

                    await network.provider.send("evm_setAutomine", [false]);
                    const joinTx = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    const exitTx = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    await network.provider.send("evm_mine");
                    await network.provider.send("evm_setAutomine", [true]);

                    const joinResult = await joinTx.wait();
                    const exitResult = await exitTx.wait();
                    expect(joinResult.blockNumber).to.be.equal(exitResult.blockNumber);
                    expect(joinResult.blockNumber).not.to.be.equal(null);

                    expect(joinTx).to.emit(cdpManagerWrapper.cdpManager(context), "Join").withArgs(context.wrappedSlp0.address, context.user1.address, lockAmount, usdpAmount);
                    expect(exitTx).to.emit(cdpManagerWrapper.cdpManager(context), "Exit").withArgs(context.wrappedSlp0.address, context.user1.address, lockAmount, usdpAmount);

                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                    expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(0, "everything were withdrawn from reward distributor");
                    expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                    expect(await context.wrappedSlp0.totalSupply()).to.be.equal(0, "everything were burned");

                    await claimReward(context.user1);
                    expect(await rewardTokenBalance(context.user1)).to.be.equal(0, "reward tokens reward got");
                });

                it(`simple case with several deposits`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, lockAmount);

                    const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));
                    const {blockNumber: deposit2Block} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));

                    const user1Proxy = await context.wrappedSlp0.usersProxies(context.user1.address);

                    const reward = sushiReward(deposit1Block, deposit2Block);
                    expect(await rewardTokenBalance(user1Proxy)).to.be.equal(reward, "reward tokens reward got to proxy");

                    const {blockNumber: withdrawalBlock} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                    expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(0, "everything were withdrawn from reward distributor");
                    expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                    expect(await context.wrappedSlp0.totalSupply()).to.be.equal(0, "everything were burned");

                    await claimReward(context.user1);
                    expect(await rewardTokenBalance(context.user1)).to.be.equal(sushiReward(deposit2Block, withdrawalBlock).add(reward), "reward tokens reward got");
                })

                it(`simple case with target repayment`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, lockAmount);
                    await context.usdp.connect(context.user1).approve(context.vault.address, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await cdpManagerWrapper.unwrapAndExitTargetRepayment(context, context.user1, context.wrappedSlp0, lockAmount.div(2), usdpAmount.div(2));
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.8'), "returned tokens to user");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount.div(2), "borrowed usdp without repaid");
                })

                it(`mint usdp only without adding collateral`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('50');

                    await prepareUserForJoin(context.user1, lockAmount);

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await wrapAndJoin(context.user1, 0, usdpAmount);
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount.mul(2), "got usdp");
                });

                it(`burn usdp without withdraw collateral`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, lockAmount);

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await unwrapAndExit(context.user1, 0, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "tokens still locked");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0, "no usdp");
                });
            });

            describe("cdp manager and direct wraps/unwraps", function () {
                it('exit without unwrap', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    await cdpManagerWrapper.exit(context, context.user1, context.wrappedSlp0, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in lp tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new wrapped tokens");

                    // rescue of tokens - rejoin and unwrapAndExit
                    await cdpManagerWrapper.join(context, context.user1, context.wrappedSlp0, lockAmount, usdpAmount);
                    await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wraped tokens");
                })

                it('exit without unwrap with direct unwrap', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    await cdpManagerWrapper.exit(context, context.user1, context.wrappedSlp0, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in lp tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new wrapped tokens");

                    await context.wrappedSlp0.connect(context.user1).withdraw(context.user1.address, lockAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wrapped tokens");
                })

                it('manual wrap and join and exit with cdp manager', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('100');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await context.wrappedSlp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "send lp tokens");
                    expect(await context.lpToken0.balanceOf(context.rewardDistributor.address)).to.be.equal(ether('0.4'), "to reward distributor");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'), "got wrapped lp tokens");

                    await cdpManagerWrapper.join(context, context.user1, context.wrappedSlp0, lockAmount, usdpAmount);
                    expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(ether('0.4'), "sent wrapped tokens to vault");

                    await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.lpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wrapped tokens");
                    expect(await context.wrappedSlp0.balanceOf(context.vault.address)).to.be.equal(0, "zero wrapped tokens");
                })
            });
        })
    })
});

async function prepareUserForJoin(user, amount) {
    await context.lpToken0.connect(user).approve(context.wrappedSlp0.address, amount);
    await context.wrappedSlp0.connect(user).approve(context.vault.address, amount);
}

async function pendingReward(user) {
    return await context.wrappedSlp0.pendingReward(user.address)
}

async function claimReward(user) {
    return await context.wrappedSlp0.connect(user).claimReward(user.address)
}

async function wrapAndJoin(user, assetAmount, usdpAmount) {
    return cdpManagerWrapper.wrapAndJoin(context, user, context.wrappedSlp0, assetAmount, usdpAmount);
}

async function unwrapAndExit(user, assetAmount, usdpAmount) {
    return cdpManagerWrapper.unwrapAndExit(context, user, context.wrappedSlp0, assetAmount, usdpAmount);
}

async function rewardTokenBalance(user) {
    return await context.rewardToken.balanceOf(user.address ? user.address : user)
}

async function mineBlocks(count) {
    for (let i = 0; i < count; ++i) {
        await network.provider.send("evm_mine");
    }
}