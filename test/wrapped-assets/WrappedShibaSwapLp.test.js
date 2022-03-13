const {expect} = require("chai");
const {ethers} = require("hardhat");
const {
    prepareWrappedSSLP, CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN,
    CASE_KEYDONIX_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN
} = require("../helpers/deploy");
const {directBonesReward, lockedBonesReward, fullBonesReward} = require("./helpers/TopDogLogic");
const {deployContract, attachContract} = require("../helpers/ethersUtils");
const {PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION} = require("../../lib/constants");
const {cdpManagerWrapper} = require("../helpers/cdpManagerWrappers");
const {ZERO_ADDRESS} = require("../helpers/deployUtils");
const Abi = require('@ethersproject/abi');

ether = ethers.utils.parseUnits;

const EPSILON = ethers.BigNumber.from('400000');

const oracleCases = [
    [CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN, 'cdp manager'],
    [CASE_KEYDONIX_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN, 'cdp manager keydonix'],
]

let context = {};
describe("WrappedShibaSwapLp", function () {

    beforeEach(async function () {
        await network.provider.send("evm_setAutomine", [true]);

        [context.deployer, context.user1, context.user2, context.user3, context.manager, context.bonesFeeReceiver] = await ethers.getSigners();
    });

    describe("Oracles independent tests", function () {
        beforeEach(async function () {
            await prepareWrappedSSLP(context, CASE_WRAPPED_TO_UNDERLYING_WRAPPED_LP_TOKEN);

            // initials distribution of lptokens to users
            await context.sslpToken0.transfer(context.user1.address, ether('1'));
            await context.sslpToken0.transfer(context.user2.address, ether('1'));
            await context.sslpToken0.transfer(context.user3.address, ether('1'));
        })

        describe("constructor", function () {
            it("wrapped token name and symbol", async function () {
                expect(await context.wrappedSslp0.symbol()).to.be.equal("wuSSLP0tokenAtokenB"); // topdog pool 0 with sslpToken0 (tokenA, tokenB)
                expect(await context.wrappedSslp0.name()).to.be.equal("Wrapped by Unit SushiSwap LP0 tokenA-tokenB"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
                expect(await context.wrappedSslp0.decimals()).to.be.equal(await context.sslpToken0.decimals());

                expect(await context.wrappedSslp1.symbol()).to.be.equal("wuSSLP1tokenCtokenD"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
                expect(await context.wrappedSslp1.name()).to.be.equal("Wrapped by Unit SushiSwap LP1 tokenC-tokenD"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
                expect(await context.wrappedSslp1.decimals()).to.be.equal(await context.sslpToken1.decimals());
            });
        });

        describe("pool direct deposit/withdraw", function () {
            it("prohibited deposit for another user", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await expect(
                    context.wrappedSslp0.connect(context.user1).deposit(context.user2.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");
            });

            it("not approved sslp token", async function () {
                const lockAmount = ether('0.4');
                await expect(
                    context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount)
                ).to.be.revertedWith("TRANSFER_FROM_FAILED");
            });

            it("zero deposit", async function () {
                await expect(
                    context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, 0)
                ).to.be.revertedWith("INVALID_AMOUNT");
            });

            it("transfer sslp token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));
                await prepareUserForJoin(context.user2, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                await context.wrappedSslp0.connect(context.user2).deposit(context.user2.address, lockAmount);

                // user cannot transfer tokens
                await expect(
                    context.wrappedSslp0.connect(context.user1).transfer(context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // another user cannot transfer tokens
                await expect(
                    context.wrappedSslp0.connect(context.user2).transfer(context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");
            });


            it("transfer from for sslp token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);

                // user cannot transfer tokens from another
                await expect(
                    context.wrappedSslp0.connect(context.user2).transferFrom(context.user1.address, context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // even if they are approved
                await context.usdp.connect(context.user1).approve(context.user2.address, lockAmount);
                await expect(
                    context.wrappedSslp0.connect(context.user2).transferFrom(context.user1.address, context.user3.address, lockAmount)
                ).to.be.revertedWith("AUTH_FAILED");

                // transfer allowance for vault tested in liquidation cases
            });

            it("simple deposit/withdraw", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);


                await context.wrappedSslp0.connect(context.user1).withdraw(context.user1.address, lockAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);

                expect(await bonesBalance(context.user1)).to.be.equal(0);
                await claimReward(context.user1)
                expect(await bonesBalance(context.user1)).not.to.be.equal(0);
            });

            it("emergency withdraw + withdraw any token", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                await context.wrappedSslp0.connect(context.user1).emergencyWithdraw();
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);

                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.sslpToken0.address, lockAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);

                expect(await bonesBalance(context.user1)).to.be.equal(0);
                await claimReward(context.user1)
                expect(await bonesBalance(context.user1)).to.be.equal(0);
            });

            it("withdraw bone token from proxy (with fee)", async function () {
                await context.wrappedSslp0.setFee(10);

                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const user1ProxyAddr = await context.wrappedSslp0.usersProxies(context.user1.address);

                // part of bones balances
                const proxyBonesBalance1 = await bonesBalance(user1ProxyAddr);
                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.boneToken.address, proxyBonesBalance1.div(2));
                const proxyBonesBalance2 = await bonesBalance(user1ProxyAddr);
                const userBonesBalance2 = await bonesBalance(context.user1);
                const feeReceiverBonesBalance2 = await bonesBalance(context.bonesFeeReceiver);

                expect(proxyBonesBalance2).to.be.equal(proxyBonesBalance1.div(2));
                expect(userBonesBalance2).to.be.equal(proxyBonesBalance1.div(2).mul(90).div(100));
                expect(feeReceiverBonesBalance2).to.be.equal(proxyBonesBalance1.div(2).mul(10).div(100));

                // all
                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.boneToken.address, proxyBonesBalance2);
                const proxyBonesBalance3 = await bonesBalance(user1ProxyAddr);
                const userBonesBalance3 = await bonesBalance(context.user1);
                const feeReceiverBonesBalance3 = await bonesBalance(context.bonesFeeReceiver);

                expect(proxyBonesBalance3).to.be.equal(0);
                expect(userBonesBalance3).to.be.equal(proxyBonesBalance1.mul(90).div(100));
                expect(feeReceiverBonesBalance3).to.be.equal(proxyBonesBalance1.mul(10).div(100));
            });

            it("withdraw some token from proxy (with fee)", async function () {
                await context.wrappedSslp0.setFee(10);

                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const user1ProxyAddr = await context.wrappedSslp0.usersProxies(context.user1.address);

                const amount = ether('1');
                await context.sslpToken1.transfer(user1ProxyAddr, amount);

                // part of balances
                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.sslpToken1.address, amount.div(2));
                const proxyBalance2 = await context.sslpToken1.balanceOf(user1ProxyAddr);
                const userBalance2 = await context.sslpToken1.balanceOf(context.user1.address);
                const feeReceiverBalance2 = await context.sslpToken1.balanceOf(context.bonesFeeReceiver.address);

                expect(proxyBalance2).to.be.equal(amount.div(2));
                expect(userBalance2).to.be.equal(amount.div(2));
                expect(feeReceiverBalance2).to.be.equal(0);

                // all
                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.sslpToken1.address, amount.div(2));
                const proxyBalance3 = await context.sslpToken1.balanceOf(user1ProxyAddr);
                const userBalance3 = await context.sslpToken1.balanceOf(context.user1.address);
                const feeReceiverBalance3 = await context.sslpToken1.balanceOf(context.bonesFeeReceiver.address);

                expect(proxyBalance3).to.be.equal(0);
                expect(userBalance3).to.be.equal(amount);
                expect(feeReceiverBalance3).to.be.equal(0);
            });

            it("no emergency withdrawal allowed with unit position", async function () {
                const lockAmount = ether('0.4');
                await prepareUserForJoin(context.user1, ether('1'));

                await wrapAndJoin(context.user1, lockAmount, 0);

                await expect(
                    context.wrappedSslp0.connect(context.user1).emergencyWithdraw()
                ).to.be.revertedWith("burn amount exceeds balance");

                await cdpManagerWrapper.exit(context, context.user1, context.wrappedSslp0, lockAmount.div(2), 0);

                await expect(
                    context.wrappedSslp0.connect(context.user1).emergencyWithdraw()
                ).to.be.revertedWith("burn amount exceeds balance");

                // full exit from unit, user got all wrapped tokens
                await cdpManagerWrapper.exit(context, context.user1, context.wrappedSslp0, lockAmount.div(2), 0);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'));

                await context.wrappedSslp0.connect(context.user1).emergencyWithdraw()
                await context.wrappedSslp0.connect(context.user1).withdrawToken(context.sslpToken0.address, lockAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);

            });
        });

        describe("proxies direct calls", function () {
            it("only manager methods", async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, lockAmount);
                await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const user1ProxyAddr = await context.wrappedSslp0.usersProxies(context.user1.address);
                expect(user1ProxyAddr).not.to.be.equal(ZERO_ADDRESS);

                const user1Proxy = await attachContract('WSSLPUserProxy', user1ProxyAddr);

                await expect(
                    user1Proxy.approveSslpToTopDog(context.sslpToken0.address)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.deposit(ether('1'))
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.withdraw(context.sslpToken0.address, ether('1'), context.user1.address)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.claimReward(context.user1.address, context.user2.address, 30)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.claimRewardFromBoneLocker(context.user1.address, context.boneLocker1.address, ether('1'), context.user1.address, 30)
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.emergencyWithdraw()
                ).to.be.revertedWith("AUTH_FAILED");

                await expect(
                    user1Proxy.withdrawToken(context.sslpToken0.address, context.user1.address, 100, context.bonesFeeReceiver.address, 10)
                ).to.be.revertedWith("AUTH_FAILED");
            });
        });

        describe("reward distribution cases", function () {
            it('consecutive deposit and withdrawal with 3 users', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);
                await prepareUserForJoin(context.user3, lockAmount);

                const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
                const {blockNumber: deposit2Block} = await wrapAndJoin(context.user2, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'), "transferred from user");
                const {blockNumber: deposit3Block} = await wrapAndJoin(context.user3, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user3.address)).to.be.equal(ether('0.6'), "transferred from user");

                expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(lockAmount.mul(3), "transferred to TopDog");
                expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(lockAmount.mul(3), "wrapped token sent to vault");
                expect(await context.wrappedSslp0.totalSupply()).to.be.equal(lockAmount.mul(3), "minted only wrapped tokens for deposited amount");

                const {blockNumber: withdrawal1Block} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");
                const {blockNumber: withdrawal2Block} = await unwrapAndExit(context.user2, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");
                const {blockNumber: withdrawal3Block} = await unwrapAndExit(context.user3, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned asset");

                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSslp0.usersProxies(context.user2.address);
                const user3Proxy = await context.wrappedSslp0.usersProxies(context.user3.address);

                // no reward sent to user on deposit/withdrawal
                expect(await bonesBalance(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user2)).to.be.equal(0);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                // but reward was sent to user proxies by topdog
                // with 3 simultaneous users we have imprecise calculations
                const user1Reward = directBonesReward(deposit1Block, deposit2Block)
                    .add(directBonesReward(deposit2Block, deposit3Block).div(2))
                    .add(directBonesReward(deposit3Block, withdrawal1Block).div(3));
                expect(await bonesBalance(user1Proxy)).to.be.closeTo(user1Reward, EPSILON);

                const user2Reward = directBonesReward(deposit2Block, deposit3Block).div(2)
                    .add(directBonesReward(deposit3Block, withdrawal1Block).div(3))
                    .add(directBonesReward(withdrawal1Block, withdrawal2Block).div(2));
                expect(await bonesBalance(user2Proxy)).to.be.closeTo(user2Reward, EPSILON);

                const user3Reward = directBonesReward(deposit3Block, withdrawal1Block).div(3)
                    .add(directBonesReward(withdrawal1Block, withdrawal2Block).div(2))
                    .add(directBonesReward(withdrawal2Block, withdrawal3Block).div(1));
                expect(await bonesBalance(user3Proxy)).to.be.closeTo(user3Reward, EPSILON);

                await claimReward(context.user1)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.equal(0);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user2)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user3)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await bonesBalance(context.user3)).to.be.closeTo(user3Reward, EPSILON);

                expect(await bonesBalance(user1Proxy)).to.be.equal(0);
                expect(await bonesBalance(user2Proxy)).to.be.equal(0);
                expect(await bonesBalance(user3Proxy)).to.be.equal(0);
            })

            it('bones distribution with non consecutive deposit and withdrawal with 3 users', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);
                await prepareUserForJoin(context.user3, lockAmount);

                const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const {blockNumber: deposit2Block} = await wrapAndJoin(context.user2, lockAmount, usdpAmount);

                const {blockNumber: withdrawal1Block} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                const {blockNumber: deposit3Block} = await wrapAndJoin(context.user3, lockAmount, usdpAmount);

                const {blockNumber: withdrawal2Block} = await unwrapAndExit(context.user2, lockAmount, usdpAmount);
                const {blockNumber: withdrawal3Block} = await unwrapAndExit(context.user3, lockAmount, usdpAmount);

                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSslp0.usersProxies(context.user2.address);
                const user3Proxy = await context.wrappedSslp0.usersProxies(context.user3.address);

                // no reward sent to user on deposit/withdrawal
                expect(await bonesBalance(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user2)).to.be.equal(0);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                const user1Reward = directBonesReward(deposit1Block, deposit2Block)
                    .add(directBonesReward(deposit2Block, withdrawal1Block).div(2));
                expect(await bonesBalance(user1Proxy)).to.be.equal(user1Reward);

                const user2Reward = directBonesReward(deposit2Block, withdrawal1Block).div(2)
                    .add(directBonesReward(withdrawal1Block, deposit3Block))
                    .add(directBonesReward(deposit3Block, withdrawal2Block).div(2));
                expect(await bonesBalance(user2Proxy)).to.be.equal(user2Reward);

                const user3Reward = directBonesReward(deposit3Block, withdrawal2Block).div(2)
                    .add(directBonesReward(withdrawal2Block, withdrawal3Block));
                expect(await bonesBalance(user3Proxy)).to.be.equal(user3Reward);

                await claimReward(context.user1)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.equal(0);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user2)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await bonesBalance(context.user3)).to.be.equal(0);

                await claimReward(context.user3)
                expect(await bonesBalance(context.user1)).to.be.closeTo(user1Reward, EPSILON);
                expect(await bonesBalance(context.user2)).to.be.closeTo(user2Reward, EPSILON);
                expect(await bonesBalance(context.user3)).to.be.closeTo(user3Reward, EPSILON);

                expect(await bonesBalance(user1Proxy)).to.be.equal(0);
                expect(await bonesBalance(user2Proxy)).to.be.equal(0);
                expect(await bonesBalance(user3Proxy)).to.be.equal(0);
            })

            it('simple case for pending reward', async function () {
                const lockAmount = ether('0.2');
                const usdpAmount = ether('0.1');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                await network.provider.send("evm_mine");
                const block2 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block2));

                await network.provider.send("evm_mine");
                const block3 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block3));

                const {blockNumber: block4} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block4));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user1)).to.be.equal(directBonesReward(block1, block4));
            })

            it('bones fee', async function () {
                await context.wrappedSslp0.setFee(10);

                const lockAmount = ether('0.2');
                const usdpAmount = ether('0.1');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                await network.provider.send("evm_mine");
                const block2 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block2).mul(90).div(100));

                await network.provider.send("evm_mine");
                const block3 = (await ethers.provider.getBlock("latest")).number
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block3).mul(90).div(100));

                const {blockNumber: block4} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block4).mul(90).div(100));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user1)).to.be.equal(directBonesReward(block1, block4).mul(90).div(100));
                expect(await bonesBalance(context.bonesFeeReceiver)).to.be.equal(directBonesReward(block1, block4).mul(10).div(100));
            })

            it('bones fee with empty receiver', async function () {
                await context.wrappedSslp0.setFee(10);
                await context.wrappedSslp0.setFeeReceiver(ZERO_ADDRESS);

                const lockAmount = ether('0.2');
                const usdpAmount = ether('0.1');

                await prepareUserForJoin(context.user1, lockAmount);

                expect(await pendingReward(context.user1)).to.be.equal(0);
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(0);

                const {blockNumber: block2} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block2));

                await claimReward(context.user1)
                expect(await pendingReward(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user1)).to.be.equal(directBonesReward(block1, block2));
                expect(await bonesBalance(context.bonesFeeReceiver)).to.be.equal(0);
            })

            it('bones fee for reward from bonelocker', async function () {
                await context.wrappedSslp0.setFee(10);

                const lockAmount = ether('0.4');
                const lockAmount2 = ether('0.2');
                const usdpAmount = ether('0.1');

                await context.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside

                await prepareUserForJoin(context.user1, lockAmount.add(lockAmount2));

                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);

                expect(await bonesBalance(user1Proxy)).to.be.equal(ether('0'));
                expect(await pendingReward(context.user1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));

                await mineBlocks(3)
                const {blockNumber: block2} = await wrapAndJoin(context.user1, lockAmount2, usdpAmount); // sent the first reward to userproxy + locked the first reward in locker
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block2).mul(90).div(100));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));


                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");
                const block2_1 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2));
                expect(await pendingReward(context.user1)).to.be.closeTo(directBonesReward(block1, block2_1).mul(90).div(100), EPSILON);
                expect(await lockerClaimableReward(context.user1)).to.be.equal(lockedBonesReward(block1, block2).mul(90).div(100)); // unlocked
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));

                await lockerClaimReward(context.user1) // sent all bones from user proxy + from locker to user
                expect(await bonesBalance(user1Proxy)).to.be.equal(0);
                expect(await lockerClaimableReward(context.user1)).to.be.equal(0);
                expect(await bonesBalance(context.user1)).to.be.equal(
                    directBonesReward(block1, block2) // were on proxy
                    .add(lockedBonesReward(block1, block2)) // got from locker
                    .mul(90).div(100) // fee
                );

                expect(await bonesBalance(context.bonesFeeReceiver)).to.be.equal(
                    directBonesReward(block1, block2) // were on proxy
                    .add(lockedBonesReward(block1, block2)) // got from locker
                    .mul(10).div(100) // fee
                );
            })

        });

        describe("bone lockers", function () {
            it('distribution bones from default bone locker', async function () {
                const lockAmount = ether('0.4');
                const lockAmount2 = ether('0.2');
                const usdpAmount = ether('0.1');

                await context.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside

                await prepareUserForJoin(context.user1, lockAmount.add(lockAmount2));

                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);

                expect(await bonesBalance(user1Proxy)).to.be.equal(ether('0'));
                expect(await pendingReward(context.user1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));

                await mineBlocks(3)
                const {blockNumber: block2} = await wrapAndJoin(context.user1, lockAmount2, usdpAmount); // sent the first reward to userproxy + locked the first reward in locker
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block1, block2));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));


                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");
                const block2_1 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2));
                expect(await pendingReward(context.user1)).to.be.closeTo(directBonesReward(block1, block2_1), EPSILON);
                expect(await lockerClaimableReward(context.user1)).to.be.equal(lockedBonesReward(block1, block2)); // unlocked
                expect(await bonesBalance(context.user1)).to.be.equal(ether('0'));


                await lockerClaimReward(context.user1) // sent all bones from user proxy + from locker to user
                const block2_2 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(ether('0')); // reward sent to user at once with reward from locker
                expect(await pendingReward(context.user1)).to.be.closeTo(directBonesReward(block2, block2_2), EPSILON);
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0')); // nothing to claim
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block2));


                ////////////////////////
                const {blockNumber: block3} = await unwrapAndExit(context.user1, lockAmount, usdpAmount); // sent the second reward to user proxy + locked the second reward in locker
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block2, block3));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block2, block3));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block2));


                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");
                const block3_1 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block2, block3));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block2, block3_1));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(lockedBonesReward(block2, block3)); // unlocked
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block2));


                await lockerClaimReward(context.user1)
                const block3_2 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(ether('0'));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block3, block3_2));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block3));


                //////////////////////
                const {blockNumber: block4} = await unwrapAndExit(context.user1, lockAmount2, usdpAmount); // sent the 3rd reward to user proxy + locked the 3rd reward in locker
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block3, block4));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block3, block4));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block3));

                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");
                const block4_1 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block3, block4));
                expect(await pendingReward(context.user1)).to.be.equal(directBonesReward(block3, block4)); // no new reward
                expect(await lockerClaimableReward(context.user1)).to.be.equal(lockedBonesReward(block3, block4)); // unlocked
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block3));

                await lockerClaimReward(context.user1);
                const block4_2 = (await ethers.provider.getBlock("latest")).number;
                expect(await bonesBalance(user1Proxy)).to.be.equal(ether('0'));
                expect(await pendingReward(context.user1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.equal(fullBonesReward(block1, block4));

                // claim with r=l
                const rlCounters = await context.boneLocker1.getLeftRightCounters(user1Proxy);
                expect(rlCounters[0]).to.be.equal(rlCounters[1])
                expect(rlCounters[0]).to.be.gt(0);
                await lockerClaimReward(context.user1, context.boneLocker1); // not failing
                await lockerClaimReward(context.user1, context.boneLocker1, 0);
                await lockerClaimReward(context.user1, context.boneLocker1, 100);
            })

            it('several bone lockers', async function () {
                const lockAmount = ether('0.2');
                const usdpAmount = ether('0.1');

                await context.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside
                const boneLocker2 = await deployContract("BoneLocker_Mock", context.boneToken.address, "0x0000000000000000000000000000000000001234", 1, 3);
                await boneLocker2.transferOwnership(context.topDog.address);

                await prepareUserForJoin(context.user1, lockAmount.mul(5));

                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                const {blockNumber: block2} = await wrapAndJoin(context.user1, lockAmount, usdpAmount); // sent the first reward to userproxy + locked the first reward in locker

                await context.topDog.boneLockerUpdate(boneLocker2.address);
                await context.topDog.setLockingPeriod(7200, 7200);

                const {blockNumber: block3} = await wrapAndJoin(context.user1, lockAmount, usdpAmount); // sent the second reward to userproxy + locked the second reward in locker2
                const {blockNumber: block4} = await wrapAndJoin(context.user1, lockAmount, usdpAmount); // sent the third reward to userproxy + locked the third reward in locker2
                const {blockNumber: block5} = await wrapAndJoin(context.user1, lockAmount, usdpAmount); // sent the forth reward to userproxy + locked the forth reward in locker2

                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");

                expect(await lockerClaimableReward(context.user1, context.boneLocker1)).to.be.equal(lockedBonesReward(block1, block2));
                expect(await lockerClaimableReward(context.user1, boneLocker2)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1, ZERO_ADDRESS)).to.be.equal(ether('0')); // current

                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");

                expect(await lockerClaimableReward(context.user1, context.boneLocker1)).to.be.equal(lockedBonesReward(block1, block2));
                expect(await lockerClaimableReward(context.user1, boneLocker2)).to.be.closeTo(lockedBonesReward(block2, block5), EPSILON);
                expect(await lockerClaimableReward(context.user1, ZERO_ADDRESS)).to.be.closeTo(lockedBonesReward(block2, block5), EPSILON);

                await lockerClaimReward(context.user1, context.boneLocker1)
                expect(await lockerClaimableReward(context.user1, context.boneLocker1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1, boneLocker2)).to.be.closeTo(lockedBonesReward(block2, block5), EPSILON);
                expect(await lockerClaimableReward(context.user1, ZERO_ADDRESS)).to.be.closeTo(lockedBonesReward(block2, block5), EPSILON);
                expect(await bonesBalance(context.user1)).to.be.closeTo(
                    lockedBonesReward(block1, block2).add(directBonesReward(block1, block5)), EPSILON
                );

                await lockerClaimReward(context.user1, boneLocker2, 1) // only 1 reward from 2nd locker
                expect(await lockerClaimableReward(context.user1, context.boneLocker1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1, boneLocker2)).to.be.closeTo(lockedBonesReward(block3, block5), EPSILON);
                expect(await lockerClaimableReward(context.user1, ZERO_ADDRESS)).to.be.closeTo(lockedBonesReward(block3, block5), EPSILON);
                expect(await bonesBalance(context.user1)).to.be.closeTo(
                    lockedBonesReward(block1, block3).add(directBonesReward(block1, block5)), EPSILON
                );

                await lockerClaimReward(context.user1, ZERO_ADDRESS, 0) // the last 2 rewards from 2nd locker (0 = all)
                expect(await lockerClaimableReward(context.user1, context.boneLocker1)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1, boneLocker2)).to.be.equal(ether('0'));
                expect(await lockerClaimableReward(context.user1, ZERO_ADDRESS)).to.be.equal(ether('0'));
                expect(await bonesBalance(context.user1)).to.be.closeTo(
                    lockedBonesReward(block1, block5).add(directBonesReward(block1, block5)), EPSILON
                );
            })

            it('read/write of unsupported bone locker', async function () {
                const lockAmount = ether('0.2');
                const usdpAmount = ether('0.1');
                await context.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside

                await prepareUserForJoin(context.user1, lockAmount.mul(5));
                const {blockNumber: block1} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));
                const {blockNumber: block2} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));
                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);

                await network.provider.send("evm_increaseTime", [3601]);
                await network.provider.send("evm_mine");

                const boneLockerInterface =  new Abi.Interface([
                    "function getClaimableAmount(address _user) view returns (uint)",
                    "function claimAll(uint256 r)",
                ]);
                const fnGetClaimableAmount = boneLockerInterface.getFunction('getClaimableAmount')
                const fnClaimAll = boneLockerInterface.getFunction('claimAll')

                const callResult1 = await context.wrappedSslp0.readBoneLocker(
                    context.user1.address,
                    context.boneLocker1.address,
                    boneLockerInterface.encodeFunctionData(fnGetClaimableAmount, [user1Proxy])
                );
                expect(callResult1.success).to.be.true;
                expect(boneLockerInterface.decodeFunctionResult(fnGetClaimableAmount, callResult1.data)[0]).to.be.equal(await context.boneLocker1.getClaimableAmount(user1Proxy))

                await expect(
                    context.wrappedSslp0.connect(context.user1).callBoneLocker(
                        context.boneLocker1.address,
                        boneLockerInterface.encodeFunctionData(fnClaimAll, [1])
                    )
                ).to.be.revertedWith("UNSUPPORTED_SELECTOR");

                await context.wrappedSslp0.connect(context.deployer).setAllowedBoneLockerSelector(
                    context.boneLocker1.address, boneLockerInterface.getSighash(fnClaimAll), true
                )

                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2)); // sent from the second deposit
                await context.wrappedSslp0.connect(context.user1).callBoneLocker(
                    context.boneLocker1.address,
                    boneLockerInterface.encodeFunctionData(fnClaimAll, [1])
                )
                expect(await bonesBalance(user1Proxy)).to.be.equal(fullBonesReward(block1, block2));

                // recheck after disable
                await context.wrappedSslp0.connect(context.deployer).setAllowedBoneLockerSelector(
                    context.boneLocker1.address, boneLockerInterface.getSighash(fnClaimAll), false
                )
                await expect(
                    context.wrappedSslp0.connect(context.user1).callBoneLocker(
                        context.boneLocker1.address,
                        boneLockerInterface.encodeFunctionData(fnClaimAll, [1])
                    )
                ).to.be.revertedWith("UNSUPPORTED_SELECTOR");
            })
        });

        describe("topdog edge cases", function () {
            it('handle change of lptopken in topdog', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, ether('1'));

                context.migratorShib = await deployContract("MigratorShib_Mock");
                await context.migratorShib.setNewToken(context.sslpToken1.address);
                await context.sslpToken1.transfer(context.migratorShib.address, ether('100'));
                await context.topDog.setMigrator(context.migratorShib.address);

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
                expect(await context.sslpToken1.balanceOf(context.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
                expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(lockAmount, "old lp tokens sent to topdog");
                expect(await context.sslpToken1.balanceOf(context.topDog.address)).to.be.equal(ether('0'), "no topdog balance in new lp token");

                expect(await context.wrappedSslp0.getUnderlyingToken()).to.be.equal(context.sslpToken0.address);
                await context.topDog.connect(context.user3).migrate(0); // anyone can migrate
                expect(await context.wrappedSslp0.getUnderlyingToken()).to.be.equal(context.sslpToken1.address);

                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
                expect(await context.sslpToken1.balanceOf(context.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
                expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(lockAmount, "old lp tokens sent to topdog");
                expect(await context.sslpToken1.balanceOf(context.topDog.address)).to.be.equal(lockAmount, "topdog balance in new lp tokens");

                await unwrapAndExit(context.user1, lockAmount, usdpAmount);

                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in old lp tokens");
                expect(await context.sslpToken1.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new lp tokens");
                expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(lockAmount, "old lp tokens didn't use");
                expect(await context.sslpToken1.balanceOf(context.topDog.address)).to.be.equal(ether('0'), "no new lp tokens left in topdog");

                // reapprove new sslp to pool
                await context.sslpToken1.connect(context.user1).approve(context.wrappedSslp0.address, ether('1'));
                // revert since new sslp is not approved for topdog
                await expect(
                  wrapAndJoin(context.user1, lockAmount, usdpAmount)
                ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");

                await context.wrappedSslp0.connect(context.user1).approveSslpToTopDog();
                await wrapAndJoin(context.user1, lockAmount, usdpAmount); // success
            })
        });

        describe("liquidations related", function () {
            it('move position', async function () {
                const lockAmount = ether('0.4');

                await prepareUserForJoin(context.user1, lockAmount);

                await context.vaultParameters.connect(context.deployer).setVaultAccess(context.deployer.address, true);

                const {blockNumber: block1} = await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                const {blockNumber: block2} = await context.wrappedSslp0.connect(context.deployer).movePosition(context.user1.address, context.user2.address, ether('0.1'));

                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSslp0.usersProxies(context.user2.address);
                expect(user2Proxy).not.to.be.equal(ZERO_ADDRESS); // created on movePosition

                expect(await bonesBalance(user1Proxy)).to.be.equal(directBonesReward(block1, block2)); // sent to proxy
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'), 'no wrapped tokens transferred');

                expect(await bonesBalance(context.user2)).to.be.equal(0);
                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSslp0.balanceOf(context.user2.address)).to.be.equal(0, 'no wrapped tokens transferred');

                // next movePosition is senselessly since contract is in inconsistent state
            })

            it('move position to the same user', async function () {
                const lockAmount = ether('0.4');

                await prepareUserForJoin(context.user1, lockAmount);
                await prepareUserForJoin(context.user2, lockAmount);

                await context.vaultParameters.connect(context.deployer).setVaultAccess(context.deployer.address, true);

                const {blockNumber: block1} = await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, ether('0.1'));
                const {blockNumber: block2} = await context.wrappedSslp0.connect(context.user2).deposit(context.user2.address, lockAmount);
                const {blockNumber: block3} = await context.wrappedSslp0.connect(context.deployer).movePosition(context.user2.address, context.user2.address, ether('0.2'));

                const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);
                const user2Proxy = await context.wrappedSslp0.usersProxies(context.user2.address);

                expect(await bonesBalance(user1Proxy)).to.be.equal(0);
                expect(await bonesBalance(user2Proxy)).to.be.equal(0);

                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user2.address)).to.be.equal(lockAmount, 'no wrapped tokens transferred');

                const {blockNumber: block4} = await context.wrappedSslp0.connect(context.deployer).movePosition(context.user2.address, context.user2.address, lockAmount);
                // nothing changes
                expect(await bonesBalance(user2Proxy)).to.be.equal(0);
                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(ether('0.6'));
                expect(await context.wrappedSslp0.balanceOf(context.user2.address)).to.be.equal(lockAmount, 'no wrapped tokens transferred');

                const {blockNumber: block5} = await context.wrappedSslp0.connect(context.user2).withdraw(context.user2.address, lockAmount); // can withdraw

                expect(await bonesBalance(user2Proxy)).to.be.equal(directBonesReward(block2, block5).mul(4).div(5))
                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(ether('1'));
                expect(await context.wrappedSslp0.balanceOf(context.user2.address)).to.be.equal(0, 'wrapped tokens burned');
            })

            it('liquidation (with moving position)', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, lockAmount);
                await context.assetsBooleanParameters.set(context.wrappedSslp0.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);
                await context.usdp.mintForTests(context.user2.address, ether('1'));
                await context.usdp.connect(context.user2).approve(context.vault.address, ether('1'));

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);

                await context.vaultManagerParameters.setInitialCollateralRatio(context.wrappedSslp0.address, ethers.BigNumber.from(9));
                await context.vaultManagerParameters.setLiquidationRatio(context.wrappedSslp0.address, ethers.BigNumber.from(10));


                await cdpManagerWrapper.triggerLiquidation(context, context.wrappedSslp0, context.user1);

                expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped tokens in vault");
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);
                expect(await context.wrappedSslp0.balanceOf(context.user2.address)).to.be.equal(0);

                await mineBlocks(10)

                await context.liquidationAuction.connect(context.user2).buyout(context.wrappedSslp0.address, context.user1.address);

                expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped tokens not in vault");
                let ownerCollateralAmount = await context.wrappedSslp0.balanceOf(context.user1.address);
                let liquidatorCollateralAmount = await context.wrappedSslp0.balanceOf(context.user2.address);
                expect(lockAmount).to.be.equal(ownerCollateralAmount.add(liquidatorCollateralAmount))

                await context.wrappedSslp0.connect(context.user1).withdraw(context.user1.address, ownerCollateralAmount);
                await context.wrappedSslp0.connect(context.user2).withdraw(context.user2.address, liquidatorCollateralAmount);

                expect(await context.wrappedSslp0.totalSupply()).to.be.equal(0);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ownerCollateralAmount.add(ether('0.6')), 'withdrawn all tokens');
                expect(await context.sslpToken0.balanceOf(context.user2.address)).to.be.equal(liquidatorCollateralAmount.add(ether('1')), 'withdrawn all tokens');
            })

            it('liquidation by owner (with moving position)', async function () {
                const lockAmount = ether('0.4');
                const usdpAmount = ether('0.2');

                await prepareUserForJoin(context.user1, lockAmount);
                await context.assetsBooleanParameters.set(context.wrappedSslp0.address, PARAM_FORCE_MOVE_WRAPPED_ASSET_POSITION_ON_LIQUIDATION, true);
                await context.usdp.connect(context.user1).approve(context.vault.address, ether('1'));

                await wrapAndJoin(context.user1, lockAmount, usdpAmount);

                await context.vaultManagerParameters.setInitialCollateralRatio(context.wrappedSslp0.address, ethers.BigNumber.from(9));
                await context.vaultManagerParameters.setLiquidationRatio(context.wrappedSslp0.address, ethers.BigNumber.from(10));

                await cdpManagerWrapper.triggerLiquidation(context, context.wrappedSslp0, context.user1);

                expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped tokens in vault");
                expect(await context.vault.collaterals(context.wrappedSslp0.address, context.user1.address)).to.be.equal(lockAmount);
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0);

                await mineBlocks(52);

                await context.liquidationAuction.connect(context.user1).buyout(context.wrappedSslp0.address, context.user1.address);

                expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped tokens not in vault");
                expect(await context.vault.collaterals(context.wrappedSslp0.address, context.user1.address)).to.be.equal(0);
                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount);

                expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, 'tokens = position');

                await context.wrappedSslp0.connect(context.user1).withdraw(context.user1.address, lockAmount);

                expect(await context.wrappedSslp0.totalSupply()).to.be.equal(0);
                expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), 'withdrawn all tokens');

                expect(await context.usdp.balanceOf(context.user1.address)).to.be.not.equal(ether('0'), 'user1 with collateral and usdp :pokerface:');
            })
        });

        describe("parameters updates", function () {
            it('set fee receiver for manager only', async function () {
                await context.wrappedSslp0.setFeeReceiver('0x0000000000000000000000000000000000000005');

                await expect(
                  context.wrappedSslp0.connect(context.user3).setFeeReceiver('0x0000000000000000000000000000000000000006')
                ).to.be.revertedWith("AUTH_FAILED");

                expect(await context.wrappedSslp0.feeReceiver()).to.be.equal('0x0000000000000000000000000000000000000005');
            })

            it('set fee for manager only', async function () {
                await context.wrappedSslp0.setFee(3);

                await expect(
                  context.wrappedSslp0.connect(context.user3).setFee(7)
                ).to.be.revertedWith("AUTH_FAILED");

                expect(await context.wrappedSslp0.feePercent()).to.be.equal(3);
            })

            it('fee in range', async function () {
                await context.wrappedSslp0.setFee(50);
                await context.wrappedSslp0.setFee(0);

                await expect(
                  context.wrappedSslp0.setFee(51)
                ).to.be.revertedWith("INVALID_FEE");

                expect(await context.wrappedSslp0.feePercent()).to.be.equal(0);
            })

            it('set allowed bone locker for manager only', async function () {
                await expect(
                  context.wrappedSslp0.connect(context.user3).setAllowedBoneLockerSelector(context.boneLocker1.address, '0x01020304', true)
                ).to.be.revertedWith("AUTH_FAILED");
            })
        });
    })

    oracleCases.forEach(params => {
        describe(`Oracles dependent tests with ${params[1]}`, function () {
            beforeEach(async function () {
                await prepareWrappedSSLP(context, params[0]);

                // initials distribution of lptokens to users
                await context.sslpToken0.transfer(context.user1.address, ether('1'));
                await context.sslpToken0.transfer(context.user2.address, ether('1'));
                await context.sslpToken0.transfer(context.user3.address, ether('1'));
            })

            describe("join/exit cases via cdp manager", function () {
                [1, 10].forEach(blockInterval =>
                    it(`simple deposit and withdrawal with interval ${blockInterval} blocks`, async function () {
                        const lockAmount = ether('0.4');
                        const usdpAmount = ether('0.2');

                        await prepareUserForJoin(context.user1, lockAmount);

                        const {blockNumber: depositBlock} = await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                        expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
                        expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");
                        expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(lockAmount, "transferred to TopDog");
                        expect(await context.sslpToken0.balanceOf(context.wrappedSslp0.address)).to.be.equal(ether('0'), "transferred not to pool");
                        expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(lockAmount, "wrapped token sent to vault");
                        expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0, "wrapped token sent not to user");
                        expect(await context.wrappedSslp0.totalSupply()).to.be.equal(lockAmount, "minted only wrapped tokens for deposited amount");

                        for (let i = 0; i < blockInterval - 1; ++i) {
                            await network.provider.send("evm_mine");
                        }

                        const {blockNumber: withdrawalBlock} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                        expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                        expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0, "returned usdp");
                        expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
                        expect(await context.sslpToken0.balanceOf(context.wrappedSslp0.address)).to.be.equal(ether('0'), "withdrawn not to pool");
                        expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                        expect(await context.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

                        await claimReward(context.user1);
                        expect(await bonesBalance(context.user1)).to.be.equal(directBonesReward(depositBlock, withdrawalBlock), "bones reward got");
                    })
                );

                it(`simple deposit in one block`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

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

                    expect(joinTx).to.emit(cdpManagerWrapper.cdpManager(context), "Join").withArgs(context.wrappedSslp0.address, context.user1.address, lockAmount, usdpAmount);
                    expect(exitTx).to.emit(cdpManagerWrapper.cdpManager(context), "Exit").withArgs(context.wrappedSslp0.address, context.user1.address, lockAmount, usdpAmount);

                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                    expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
                    expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                    expect(await context.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

                    await claimReward(context.user1);
                    expect(await bonesBalance(context.user1)).to.be.equal(0, "bones reward got");
                });

                it(`simple case with several deposits`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, lockAmount);

                    const {blockNumber: deposit1Block} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));
                    const {blockNumber: deposit2Block} = await wrapAndJoin(context.user1, lockAmount.div(2), usdpAmount.div(2));

                    const user1Proxy = await context.wrappedSslp0.usersProxies(context.user1.address);

                    const reward = directBonesReward(deposit1Block, deposit2Block);
                    expect(await bonesBalance(user1Proxy)).to.be.equal(reward, "bones reward got to proxy");

                    const {blockNumber: withdrawalBlock} = await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
                    expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
                    expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
                    expect(await context.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

                    await claimReward(context.user1);
                    expect(await bonesBalance(context.user1)).to.be.equal(directBonesReward(deposit2Block, withdrawalBlock).add(reward), "bones reward got");
                })

                it(`simple case with target repayment`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, lockAmount);
                    await context.usdp.connect(context.user1).approve(context.vault.address, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await cdpManagerWrapper.unwrapAndExitTargetRepayment(context, context.user1, context.wrappedSslp0, ether('0.2'), ether('0.1'));
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.8'), "returned tokens to user");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(ether('0.1'), "got usdp without fee");
                })

                it(`mint usdp only without adding collateral`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.1');

                    await prepareUserForJoin(context.user1, lockAmount);

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await wrapAndJoin(context.user1, 0, usdpAmount);
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount.mul(2), "got usdp");
                });

                it(`burn usdp without withdraw collateral`, async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, lockAmount);

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(usdpAmount, "got usdp");

                    await unwrapAndExit(context.user1, 0, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "tokens still locked");
                    expect(await context.usdp.balanceOf(context.user1.address)).to.be.equal(0, "no usdp");
                });
            });

            describe("cdp manager and direct wraps/unwraps", function () {
                it('exit without unwrap', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    await cdpManagerWrapper.exit(context, context.user1, context.wrappedSslp0, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in lp tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new wrapped tokens");

                    // rescue of tokens - rejoin and unwrapAndExit
                    await cdpManagerWrapper.join(context, context.user1, context.wrappedSslp0, lockAmount, usdpAmount);
                    await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wraped tokens");
                })

                it('exit without unwrap with direct unwrap', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await wrapAndJoin(context.user1, lockAmount, usdpAmount);
                    await cdpManagerWrapper.exit(context, context.user1, context.wrappedSslp0, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "nothing returned in lp tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(lockAmount, "but returned in new wrapped tokens");

                    await context.wrappedSslp0.connect(context.user1).withdraw(context.user1.address, lockAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wrapped tokens");
                })

                it('manual wrap and join and exit with cdp manager', async function () {
                    const lockAmount = ether('0.4');
                    const usdpAmount = ether('0.2');

                    await prepareUserForJoin(context.user1, ether('1'));

                    await context.wrappedSslp0.connect(context.user1).deposit(context.user1.address, lockAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('0.6'), "send lp tokens");
                    expect(await context.sslpToken0.balanceOf(context.topDog.address)).to.be.equal(ether('0.4'), "top TopDog");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(ether('0.4'), "got wrapped lp tokens");

                    await cdpManagerWrapper.join(context, context.user1, context.wrappedSslp0, lockAmount, usdpAmount);
                    expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(ether('0.4'), "sent wrapped tokens to vault");

                    await unwrapAndExit(context.user1, lockAmount, usdpAmount);
                    expect(await context.sslpToken0.balanceOf(context.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.user1.address)).to.be.equal(0, "zero wrapped tokens");
                    expect(await context.wrappedSslp0.balanceOf(context.vault.address)).to.be.equal(0, "zero wrapped tokens");
                })
            });
        })
    })
});

async function prepareUserForJoin(user, amount) {
    await context.sslpToken0.connect(user).approve(context.wrappedSslp0.address, amount);
    await context.wrappedSslp0.connect(user).approve(context.vault.address, amount);
}

async function pendingReward(user) {
    return await context.wrappedSslp0.pendingReward(user.address)
}

async function claimReward(user) {
    return await context.wrappedSslp0.connect(user).claimReward(user.address)
}

async function wrapAndJoin(user, assetAmount, usdpAmount) {
    return cdpManagerWrapper.wrapAndJoin(context, user, context.wrappedSslp0, assetAmount, usdpAmount);
}

async function unwrapAndExit(user, assetAmount, usdpAmount) {
    return cdpManagerWrapper.unwrapAndExit(context, user, context.wrappedSslp0, assetAmount, usdpAmount);
}

async function bonesBalance(user) {
    return await context.boneToken.balanceOf(user.address ? user.address : user)
}

async function lockerClaimReward(user, locker = context.boneLocker1, maxRewardsAtOnce = 10) {
    await context.wrappedSslp0.connect(user).claimRewardFromBoneLocker(locker.address ? locker.address : locker, maxRewardsAtOnce); // everyone can claim
}

async function lockerClaimableReward(user, locker = context.boneLocker1) {
    return await context.wrappedSslp0.connect(context.user3).getClaimableRewardFromBoneLocker(user.address, locker.address ? locker.address : locker); // everyone can view info
}

async function mineBlocks(count) {
    for (let i = 0; i < count; ++i) {
        await network.provider.send("evm_mine");
    }
}