const {expect} = require("chai");
const {ethers} = require("hardhat");
const {prepareWrappedSSLP} = require("../helpers/deploy");
const {directBonesReward, lockedBonesReward, fullBonesReward} = require("./helpers/TopDogLogic");
const {deployContract} = require("../helpers/ethersUtils");

ether = ethers.utils.parseUnits;

const EPSILON = ethers.BigNumber.from('20000000');

let context;

async function prepareUserForJoin(user, amount) {
    await context.sslpToken0.connect(user).approve(context.wrappedSslp0.address, amount);
    await context.wrappedSslp0.connect(user).approve(context.vault.address, amount);
}

async function pendingReward(user) {
    return await context.wrappedSslp0.pendingReward(user.address)
}

async function claimReward(user) {
    return await context.wrappedSslp0.connect(user).claimReward()
}

async function wrapAndJoin(user, assetAmount, usdpAmount) {
    return await context.cdpManager.connect(user).wrapAndJoin(context.wrappedSslp0.address, assetAmount, usdpAmount);
}

async function unwrapAndExit(user, assetAmount, usdpAmount) {
    return await context.cdpManager.connect(user).unwrapAndExit(context.wrappedSslp0.address, assetAmount, usdpAmount);
}

async function bonesBalance(user) {
    return await context.boneToken.balanceOf(user.address)
}

async function lockerClaimReward(fromLocker = 0, toLocker = 0, maxRewardsAtOnce = 10) {
    await context.wrappedSslp0.connect(context.user3).claimRewardFromBoneLockers(fromLocker, toLocker, maxRewardsAtOnce); // everyone can claim
}

async function mineBlocks(count) {
    for (let i = 0; i < count; ++i) {
        await network.provider.send("evm_mine");
    }
}

describe("WrappedShibaSwapLpFactory", function () {

    beforeEach(async function () { // todo keydonix case
        context = this;
        await network.provider.send("evm_setAutomine", [true]);

        [this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();
        await prepareWrappedSSLP(this)

        // initials distribution of lptokens to users
        await this.sslpToken0.transfer(this.user1.address, ether('1'));
        await this.sslpToken0.transfer(this.user2.address, ether('1'));
        await this.sslpToken0.transfer(this.user3.address, ether('1'));
    });

    it("wrapped token name and symbol", async function () {
        expect(await this.wrappedSslp0.symbol()).to.be.equal("wuSSLP0tokenAtokenB"); // topdog pool 0 with sslpToken0 (tokenA, tokenB)
        expect(await this.wrappedSslp0.name()).to.be.equal("Wrapped by Unit SushiSwap LP0 tokenA-tokenB"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
        expect(await this.wrappedSslp0.decimals()).to.be.equal(await this.sslpToken0.decimals());

        expect(await this.wrappedSslp1.symbol()).to.be.equal("wuSSLP1tokenCtokenD"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
        expect(await this.wrappedSslp1.name()).to.be.equal("Wrapped by Unit SushiSwap LP1 tokenC-tokenD"); // topdog pool 1 with sslpToken1 (tokenC, tokenD)
        expect(await this.wrappedSslp1.decimals()).to.be.equal(await this.sslpToken1.decimals());
    });

    [1, 10].forEach(blockInterval =>
        it(`simple deposit and withdrawal with interval ${blockInterval} blocks`, async function () {
            const lockAmount = ether('0.4');
            const usdpAmount = ether('0.2');

            await prepareUserForJoin(this.user1, lockAmount);

            const {blockNumber: depositBlock} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
            expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
            expect(await this.usdp.balanceOf(this.user1.address)).to.be.equal(usdpAmount, "got usdp");
            expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(lockAmount, "transferred to TopDog");
            expect(await this.sslpToken0.balanceOf(this.wrappedSslp0.address)).to.be.equal(ether('0'), "transferred not to pool");
            expect(await this.wrappedSslp0.balanceOf(this.vault.address)).to.be.equal(lockAmount, "wrapped token sent to vault");
            expect(await this.wrappedSslp0.totalSupply()).to.be.equal(lockAmount, "minted only wrapped tokens for deposited amount");

            for (let i = 0; i < blockInterval - 1; ++i) {
                await network.provider.send("evm_mine");
            }

            const {blockNumber: withdrawalBlock} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
            expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
            expect(await this.usdp.balanceOf(this.user1.address)).to.be.equal(0, "returned usdp");
            expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
            expect(await this.sslpToken0.balanceOf(this.wrappedSslp0.address)).to.be.equal(ether('0'), "withdrawn not to pool");
            expect(await this.wrappedSslp0.balanceOf(this.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
            expect(await this.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

            expect(await bonesBalance(this.user1)).to.be.equal(directBonesReward(depositBlock, withdrawalBlock), "bones reward got");
        })
    );

    it(`simple deposit in one block`, async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);

        await network.provider.send("evm_setAutomine", [false]);
        const joinTx = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        const exitTx = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        await network.provider.send("evm_mine");
        await network.provider.send("evm_setAutomine", [true]);

        const joinResult = await joinTx.wait();
        const exitResult = await exitTx.wait();
        expect(joinResult.blockNumber).to.be.equal(exitResult.blockNumber);
        expect(joinResult.blockNumber).not.to.be.equal(null);

        expect(joinTx).to.emit(this.cdpManager, "Join").withArgs(this.wrappedSslp0.address, this.user1.address, lockAmount, usdpAmount);
        expect(exitTx).to.emit(this.cdpManager, "Exit").withArgs(this.wrappedSslp0.address, this.user1.address, lockAmount, usdpAmount);

        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
        expect(await this.wrappedSslp0.balanceOf(this.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
        expect(await this.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

        expect(await bonesBalance(this.user1)).to.be.equal(0, "bones reward got");
    });

    it(`simple case with several deposits`, async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);

        const {blockNumber: deposit1Block} = await wrapAndJoin(this.user1, lockAmount.div(2), usdpAmount.div(2));
        const {blockNumber: deposit2Block} = await wrapAndJoin(this.user1, lockAmount.div(2), usdpAmount.div(2));
        const reward = directBonesReward(deposit1Block, deposit2Block);
        expect(await bonesBalance(this.user1)).to.be.equal(reward, "bones reward got");

        const {blockNumber: withdrawalBlock} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned all tokens to user");
        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(0, "everything were withdrawn from TopDog");
        expect(await this.wrappedSslp0.balanceOf(this.vault.address)).to.be.equal(0, "wrapped token withdrawn from vault");
        expect(await this.wrappedSslp0.totalSupply()).to.be.equal(0, "everything were burned");

        expect(await bonesBalance(this.user1)).to.be.equal(directBonesReward(deposit2Block, withdrawalBlock).add(reward), "bones reward got");
    })

    it(`simple case with target repayment`, async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);
        await this.usdp.connect(this.user1).approve(this.vault.address, ether('1'));

        await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "sent tokens");
        expect(await this.usdp.balanceOf(this.user1.address)).to.be.equal(usdpAmount, "got usdp");

        await context.cdpManager.connect(this.user1).unwrapAndExitTargetRepayment(context.wrappedSslp0.address, ether('0.2'), ether('0.1'));
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.8'), "returned tokens to user");
        expect(await this.usdp.balanceOf(this.user1.address)).to.be.equal(ether('0.1'), "got usdp without fee");
    })

    it('consecutive deposit and withdrawal with 3 users', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        const {blockNumber: deposit1Block} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "transferred from user");
        const {blockNumber: deposit2Block} = await wrapAndJoin(this.user2, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user2.address)).to.be.equal(ether('0.6'), "transferred from user");
        const {blockNumber: deposit3Block} = await wrapAndJoin(this.user3, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user3.address)).to.be.equal(ether('0.6'), "transferred from user");

        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(lockAmount.mul(3), "transferred to TopDog");
        expect(await this.wrappedSslp0.balanceOf(this.vault.address)).to.be.equal(lockAmount.mul(3), "wrapped token sent to vault");
        expect(await this.wrappedSslp0.totalSupply()).to.be.equal(lockAmount.mul(3), "minted only wrapped tokens for deposited amount");

        const {blockNumber: withdrawal1Block} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned asset");
        const {blockNumber: withdrawal2Block} = await unwrapAndExit(this.user2, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned asset");
        const {blockNumber: withdrawal3Block} = await unwrapAndExit(this.user3, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "returned asset");

        // with 3 simultaneous users we have imprecise calculations
        const user1Reward = directBonesReward(deposit1Block, deposit2Block)
            .add(directBonesReward(deposit2Block, deposit3Block).div(2))
            .add(directBonesReward(deposit3Block, withdrawal1Block).div(3));
        expect(await bonesBalance(this.user1)).to.be.closeTo(user1Reward, EPSILON);

        const user2Reward = directBonesReward(deposit2Block, deposit3Block).div(2)
            .add(directBonesReward(deposit3Block, withdrawal1Block).div(3))
            .add(directBonesReward(withdrawal1Block, withdrawal2Block).div(2));
        expect(await bonesBalance(this.user2)).to.be.closeTo(user2Reward, EPSILON);

        const user3Reward = directBonesReward(deposit3Block, withdrawal1Block).div(3)
            .add(directBonesReward(withdrawal1Block, withdrawal2Block).div(2))
            .add(directBonesReward(withdrawal2Block, withdrawal3Block).div(1));
        expect(await bonesBalance(this.user3)).to.be.closeTo(user3Reward, EPSILON);

        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(ether('0'), EPSILON);
    })

    it('bones distribution with non consecutive deposit and withdrawal with 3 users', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        const {blockNumber: deposit1Block} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit2Block} = await wrapAndJoin(this.user2, lockAmount, usdpAmount);

        const {blockNumber: withdrawal1Block} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit3Block} = await wrapAndJoin(this.user3, lockAmount, usdpAmount);

        const {blockNumber: withdrawal2Block} = await unwrapAndExit(this.user2, lockAmount, usdpAmount);
        const {blockNumber: withdrawal3Block} = await unwrapAndExit(this.user3, lockAmount, usdpAmount);

        const user1Reward = directBonesReward(deposit1Block, deposit2Block)
            .add(directBonesReward(deposit2Block, withdrawal1Block).div(2));
        expect(await bonesBalance(this.user1)).to.be.equal(user1Reward);

        const user2Reward = directBonesReward(deposit2Block, withdrawal1Block).div(2)
            .add(directBonesReward(withdrawal1Block, deposit3Block))
            .add(directBonesReward(deposit3Block, withdrawal2Block).div(2));
        expect(await bonesBalance(this.user2)).to.be.equal(user2Reward);

        const user3Reward = directBonesReward(deposit3Block, withdrawal2Block).div(2)
            .add(directBonesReward(withdrawal2Block, withdrawal3Block));
        expect(await bonesBalance(this.user3)).to.be.equal(user3Reward);

        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(0);
    })

    it('deposited bones to wrapped lp before first lp deposit', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        const depositedBones = ethers.BigNumber.from('1111111111111111111'); // 1.(1) ether
        this.boneToken.testMint(this.wrappedSslp0.address, depositedBones);

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        const {blockNumber: deposit1Block} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit2Block} = await wrapAndJoin(this.user2, lockAmount, usdpAmount);
        const {blockNumber: withdrawal1Block} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit3Block} = await wrapAndJoin(this.user3, lockAmount, usdpAmount);
        const {blockNumber: withdrawal2Block} = await unwrapAndExit(this.user2, lockAmount, usdpAmount);
        const {blockNumber: withdrawal3Block} = await unwrapAndExit(this.user3, lockAmount, usdpAmount);

        // not all initial bones distributed bcs of imprecise distribution calculations
        const user1Reward = depositedBones
            .add(directBonesReward(deposit1Block, deposit2Block))
            .add(directBonesReward(deposit2Block, withdrawal1Block).div(2));
        expect(await bonesBalance(this.user1)).to.be.closeTo(user1Reward, EPSILON);

        const user2Reward = directBonesReward(deposit2Block, withdrawal1Block).div(2)
            .add(directBonesReward(withdrawal1Block, deposit3Block))
            .add(directBonesReward(deposit3Block, withdrawal2Block).div(2));
        expect(await bonesBalance(this.user2)).to.be.equal(user2Reward);

        const user3Reward = directBonesReward(deposit3Block, withdrawal2Block).div(2)
            .add(directBonesReward(withdrawal2Block, withdrawal3Block));
        expect(await bonesBalance(this.user3)).to.be.equal(user3Reward);

        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(ether('0'), EPSILON);
    })

    it('withdraw all with remainder on wrapped lp and then deposit+withdraw', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        await wrapAndJoin(this.user2, lockAmount, usdpAmount);
        await wrapAndJoin(this.user3, lockAmount, usdpAmount);

        await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        await unwrapAndExit(this.user2, lockAmount, usdpAmount);
        await unwrapAndExit(this.user3, lockAmount, usdpAmount);

        const user1InitialReward = await bonesBalance(this.user1);
        const user2InitialReward = await bonesBalance(this.user2);
        const user3InitialReward = await bonesBalance(this.user3);
        const remainder = await bonesBalance(this.wrappedSslp0);
        expect(remainder).not.to.be.equal(0); // remainder

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        const {blockNumber: deposit1Block} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit2Block} = await wrapAndJoin(this.user2, lockAmount, usdpAmount);
        const {blockNumber: withdrawal1Block} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        const {blockNumber: deposit3Block} = await wrapAndJoin(this.user3, lockAmount, usdpAmount);
        const {blockNumber: withdrawal2Block} = await unwrapAndExit(this.user2, lockAmount, usdpAmount);
        const {blockNumber: withdrawal3Block} = await unwrapAndExit(this.user3, lockAmount, usdpAmount);

        const user1Reward = remainder
            .add(user1InitialReward)
            .add(directBonesReward(deposit1Block, deposit2Block))
            .add(directBonesReward(deposit2Block, withdrawal1Block).div(2));
        expect(await bonesBalance(this.user1)).to.be.closeTo(user1Reward, EPSILON);

        const user2Reward = user2InitialReward
            .add(directBonesReward(deposit2Block, withdrawal1Block).div(2))
            .add(directBonesReward(withdrawal1Block, deposit3Block))
            .add(directBonesReward(deposit3Block, withdrawal2Block).div(2));
        expect(await bonesBalance(this.user2)).to.be.equal(user2Reward);

        const user3Reward = user3InitialReward
            .add(directBonesReward(deposit3Block, withdrawal2Block).div(2))
            .add(directBonesReward(withdrawal2Block, withdrawal3Block));
        expect(await bonesBalance(this.user3)).to.be.equal(user3Reward);

        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(ether('0'), EPSILON);
    })

    it('simple case for pending reward', async function () {
        const lockAmount = ether('0.2');
        const usdpAmount = ether('0.1');

        await prepareUserForJoin(this.user1, lockAmount);

        expect(await pendingReward(this.user1)).to.be.equal(0);
        const {blockNumber: block1} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        expect(await pendingReward(this.user1)).to.be.equal(0);

        await network.provider.send("evm_mine");
        const block2 = (await ethers.provider.getBlock("latest")).number
        expect(await pendingReward(this.user1)).to.be.equal(directBonesReward(block1, block2));

        await network.provider.send("evm_mine");
        const block3 = (await ethers.provider.getBlock("latest")).number
        expect(await pendingReward(this.user1)).to.be.equal(directBonesReward(block1, block3));

        const {blockNumber: block4} = await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        expect(await pendingReward(this.user1)).to.be.equal(0);
    })

    it('complex case: bones distribution with non consecutive multiple deposit and withdrawal and reward claims with 3 users', async function () {
        const lockAmount = ether('0.5');
        const lockAmount2 = ether('1');
        const usdpAmount = ether('0.1');
        const usdpAmount2 = ether('0.2');

        await prepareUserForJoin(this.user1, ether('10'));
        await prepareUserForJoin(this.user2, ether('10'));
        await prepareUserForJoin(this.user3, ether('10'));

        let usersPendingReward = {
            1: ether('0'),
            2: ether('0'),
            3: ether('0'),
        };
        let usersWithdrawnReward = {
            1: ether('0'),
            2: ether('0'),
            3: ether('0'),
        };

        async function updateRewardsByPrevBlockAndCheck(block1, block2, actionUserNumber, user1Balance, user2Balance, user3Balance) {
            const balances = {
                1: ether(user1Balance),
                2: ether(user2Balance),
                3: ether(user3Balance),
            }
            const balancesSum = balances[1].add(balances[2]).add(balances[3])

            usersPendingReward[1] = usersPendingReward[1].add(directBonesReward(block1, block2).mul(balances[1]).div(balancesSum));
            usersPendingReward[2] = usersPendingReward[2].add(directBonesReward(block1, block2).mul(balances[2]).div(balancesSum));
            usersPendingReward[3] = usersPendingReward[3].add(directBonesReward(block1, block2).mul(balances[3]).div(balancesSum));

            if (actionUserNumber) {
                // compare reward of user made action, since reward is sending on action
                usersWithdrawnReward[actionUserNumber] = usersWithdrawnReward[actionUserNumber].add(usersPendingReward[actionUserNumber]);
                usersPendingReward[actionUserNumber] = ether('0');
            }

            expect(await pendingReward(context.user1)).to.be.closeTo(usersPendingReward[1], EPSILON);
            expect(await pendingReward(context.user2)).to.be.closeTo(usersPendingReward[2], EPSILON);
            expect(await pendingReward(context.user3)).to.be.closeTo(usersPendingReward[3], EPSILON);
            expect(await bonesBalance(context.user1)).to.be.closeTo(usersWithdrawnReward[1], EPSILON);
            expect(await bonesBalance(context.user2)).to.be.closeTo(usersWithdrawnReward[2], EPSILON);
            expect(await bonesBalance(context.user3)).to.be.closeTo(usersWithdrawnReward[3], EPSILON);
        }

        const {blockNumber: block1} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // 1-0.5, 2-0, 3-0
        const {blockNumber: block2} = await wrapAndJoin(this.user2, lockAmount2, usdpAmount2); // 1-0.5, 2-1, 3-0
        await updateRewardsByPrevBlockAndCheck(block1, block2, null, '0.5', '0', '0');

        const {blockNumber: block3} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // 1-1, 2-1, 3-0
        await updateRewardsByPrevBlockAndCheck(block2, block3, 1, '0.5', '1', '0');

        const {blockNumber: block4} = await unwrapAndExit(this.user2, lockAmount, usdpAmount); // 1-1, 2-0.5, 3-0
        await updateRewardsByPrevBlockAndCheck(block3, block4, 2, '1', '1', '0');

        const {blockNumber: block5} = await claimReward(this.user1); // 1-1, 2-0.5, 3-0
        await updateRewardsByPrevBlockAndCheck(block4, block5, 1, '1', '0.5', '0');

        const {blockNumber: block6} = await wrapAndJoin(this.user3, lockAmount2, usdpAmount2); // 1-1, 2-0.5, 3-1
        await updateRewardsByPrevBlockAndCheck(block5, block6, null, '1', '0.5', '0');

        await network.provider.send("evm_mine");
        await network.provider.send("evm_mine");
        await network.provider.send("evm_mine");

        const {blockNumber: block7} = await wrapAndJoin(this.user2, lockAmount, usdpAmount); // 1-1, 2-1, 3-1
        await updateRewardsByPrevBlockAndCheck(block6, block7, 2, '1', '0.5', '1');
        expect(block7 - block6).to.be.equal(4)

        const {blockNumber: block8} = await claimReward(this.user3); // 1-1, 2-1, 3-1
        await updateRewardsByPrevBlockAndCheck(block7, block8, 3, '1', '1', '1');

        const {blockNumber: block9} = await unwrapAndExit(this.user3, lockAmount, usdpAmount); // 1-1, 2-1, 3-0.5
        await updateRewardsByPrevBlockAndCheck(block8, block9, 3, '1', '1', '1');

        await network.provider.send("evm_mine");
        await network.provider.send("evm_mine");

        const {blockNumber: block10} = await claimReward(this.user3); // 1-1, 2-1, 3-0.5
        await updateRewardsByPrevBlockAndCheck(block9, block10, 3, '1', '1', '0.5');
        expect(block10 - block9).to.be.equal(3)

        const {blockNumber: block11} = await unwrapAndExit(this.user1, lockAmount, usdpAmount); // 1-0.5, 2-1, 3-0.5
        await updateRewardsByPrevBlockAndCheck(block10, block11, 1, '1', '1', '0.5');

        const {blockNumber: block12} = await claimReward(this.user1); // 1-0.5, 2-1, 3-0.5
        await updateRewardsByPrevBlockAndCheck(block11, block12, 1, '0.5', '1', '0.5');

        const {blockNumber: block13} = await unwrapAndExit(this.user1, lockAmount, usdpAmount); // 1-0, 2-1, 3-0.5
        await updateRewardsByPrevBlockAndCheck(block12, block13, 1, '0.5', '1', '0.5');

        const {blockNumber: block14} = await unwrapAndExit(this.user3, lockAmount, usdpAmount); // 1-0, 2-1, 3-0
        await updateRewardsByPrevBlockAndCheck(block13, block14, 3, '0', '1', '0.5');

        const {blockNumber: block15} = await unwrapAndExit(this.user2, lockAmount2, usdpAmount2); // 1-0, 2-0, 3-0
        await updateRewardsByPrevBlockAndCheck(block14, block15, 2, '0', '1', '0');

        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(ether('0'), EPSILON);
    })

    it('distribution bones from bone locker', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        async function lockerClaimableReward(fromLocker = 0, toLocker = 0) {
            let [claimableReward] = await context.wrappedSslp0.connect(context.user3).getClaimableRewardAmountFromBoneLockers(fromLocker, toLocker); // everyone can view info
            return claimableReward;
        }

        await this.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside

        await prepareUserForJoin(this.user1, lockAmount);
        await prepareUserForJoin(this.user2, lockAmount);
        await prepareUserForJoin(this.user3, lockAmount);

        const {blockNumber: block1} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        await mineBlocks(3)
        const {blockNumber: block2} = await wrapAndJoin(this.user2, lockAmount, usdpAmount); // sent the first reward to pool + locked the first reward in locker
        expect(await lockerClaimableReward()).to.be.equal(ether('0'));

        await network.provider.send("evm_increaseTime", [3601]);
        await network.provider.send("evm_mine");
        expect(await lockerClaimableReward()).to.be.equal(lockedBonesReward(block1, block2));

        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(directBonesReward(block1, block2)); // on pool only direct reward
        await lockerClaimReward()
        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(fullBonesReward(block1, block2)); // on pool all reward
        expect(await lockerClaimableReward()).to.be.equal(ether('0')); // nothing to claim

        ////////////////////////
        const {blockNumber: block3} = await unwrapAndExit(this.user1, lockAmount, usdpAmount); // sent the second reward to pool + locked the second reward in locker
        let reward = directBonesReward(block1, block2)
            .add(directBonesReward(block2, block3).div(2))
            .add(lockedBonesReward(block1, block2).div(2)) // locked reward distributed between 2 and 3, so divided between 2 users
        expect(await bonesBalance(this.user1)).to.be.equal(reward);
        expect(await lockerClaimableReward()).to.be.equal(ether('0'));

        await network.provider.send("evm_increaseTime", [3601]);
        await network.provider.send("evm_mine");
        expect(await lockerClaimableReward()).to.be.equal(lockedBonesReward(block2, block3));

        let currentPoolReward = await bonesBalance(this.wrappedSslp0);
        await lockerClaimReward()
        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(currentPoolReward.add(lockedBonesReward(block2, block3)));
        expect(await lockerClaimableReward()).to.be.equal(ether('0'));

        //////////////////////
        const {blockNumber: block4} = await unwrapAndExit(this.user2, lockAmount, usdpAmount); // sent the 3rd reward to pool + locked the 3rd reward in locker
        reward = directBonesReward(block2, block3).div(2)
            .add(lockedBonesReward(block1, block2).div(2)) // locked reward distributed between 2 and 3, so divided between 2 users
            .add(directBonesReward(block3, block4))
            .add(lockedBonesReward(block2, block3)) // locked reward distributed only to user 2 since it claimed after exit of the first user
        expect(await bonesBalance(this.user2)).to.be.equal(reward);
        expect(await lockerClaimableReward()).to.be.equal(ether('0'));

        await network.provider.send("evm_increaseTime", [3601]);
        await network.provider.send("evm_mine");
        expect(await lockerClaimableReward()).to.be.equal(lockedBonesReward(block3, block4));

        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(ether('0')); // everything was withdrawn
        await lockerClaimReward()
        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(lockedBonesReward(block3, block4)); // bones on pool, the first deposited user will get it
        expect(await lockerClaimableReward()).to.be.equal(ether('0'));

        ///////////////////
        let remainder = lockedBonesReward(block3, block4);
        const {blockNumber: block5} = await wrapAndJoin(this.user3, lockAmount, usdpAmount);
        const {blockNumber: block6} = await unwrapAndExit(this.user3, lockAmount, usdpAmount);
        expect(await bonesBalance(this.user3)).to.be.equal(remainder.add(directBonesReward(block5, block6)));
    })

    it('several bone lockers', async function () {
        const lockAmount = ether('0.02');
        const usdpAmount = ether('0.01');

        async function lockerClaimableReward(fromLocker = 0, toLocker = 0) {
            return await context.wrappedSslp0.connect(context.user3).getClaimableRewardAmountFromBoneLockers(fromLocker, toLocker); // everyone can view info
        }

        async function getBoneLockerRewardsCount(fromLocker = 0, toLocker = 0) {
            return await context.wrappedSslp0.connect(context.user3).getBoneLockerRewardsCount(fromLocker, toLocker); // everyone can view info
        }

        await this.topDog.setLockingPeriod(3600, 3600); // topdog calls bonelocker inside

        await prepareUserForJoin(this.user1, ether('1'));

        const boneLocker2 = await deployContract("BoneLocker_Mock", context.boneToken.address, "0x0000000000000000000000000000000000001234", 1, 3);
        await boneLocker2.transferOwnership(context.topDog.address);
        const boneLocker3 = await deployContract("BoneLocker_Mock", context.boneToken.address, "0x0000000000000000000000000000000000001234", 1, 3);
        await boneLocker3.transferOwnership(context.topDog.address);

        const {blockNumber: block1} = await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        await mineBlocks(2) // fot different bones reward
        const {blockNumber: block2} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the first reward in locker1
        await mineBlocks(1)
        const {blockNumber: block3} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the 2nd reward in locker1
        await mineBlocks(3)
        const {blockNumber: block4} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the 3nd reward in locker1
        await mineBlocks(5)

        await this.topDog.boneLockerUpdate(boneLocker2.address);
        await this.topDog.setLockingPeriod(7200, 7200);

        const {blockNumber: block5} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the first reward in locker2
        await mineBlocks(3)
        const {blockNumber: block6} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the 2nd reward in locker2
        await mineBlocks(7)
        const {blockNumber: block7} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the 3rd reward in locker2
        await mineBlocks(1)

        await this.topDog.boneLockerUpdate(boneLocker3.address);
        await this.topDog.setLockingPeriod(10000, 10000);

        const {blockNumber: block8} = await wrapAndJoin(this.user1, lockAmount, usdpAmount); // locked the first reward in locker3

        let claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.equal(ether('0'));
        expect(claimableReward[1]).to.be.equal(ether('0'));
        expect(claimableReward[2]).to.be.equal(ether('0'));

        const expectedLocker1Amount = lockedBonesReward(block1, block2)
            .add(lockedBonesReward(block2, block3))
            .add(lockedBonesReward(block3, block4));
        const expectedLocker2Amount = lockedBonesReward(block4, block5)
            .add(lockedBonesReward(block5, block6))
            .add(lockedBonesReward(block6, block7));
        const expectedLocker3Amount = lockedBonesReward(block7, block8);

        await network.provider.send("evm_increaseTime", [4000]);
        await network.provider.send("evm_mine");
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker1Amount, EPSILON);
        expect(claimableReward[1]).to.be.equal(ether('0'));
        expect(claimableReward[2]).to.be.equal(ether('0'));
        claimableReward = await lockerClaimableReward(0, 0);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker1Amount, EPSILON);
        claimableReward = await lockerClaimableReward(2, 2);
        expect(claimableReward[0]).to.be.equal(ether('0'));
        let claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(3);
        expect(claimableRewardCounts[1]).to.be.equal(0);
        expect(claimableRewardCounts[2]).to.be.equal(0);

        await network.provider.send("evm_increaseTime", [4000]);
        await network.provider.send("evm_mine");
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker1Amount, EPSILON);
        expect(claimableReward[1]).to.be.closeTo(expectedLocker2Amount, EPSILON);
        expect(claimableReward[2]).to.be.equal(ether('0'));
        claimableReward = await lockerClaimableReward(1, 1);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker2Amount, EPSILON);
        claimableReward = await lockerClaimableReward(2, 2);
        expect(claimableReward[0]).to.be.equal(ether('0'));
        claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(3);
        expect(claimableRewardCounts[1]).to.be.equal(3);
        expect(claimableRewardCounts[2]).to.be.equal(0);

        await network.provider.send("evm_increaseTime", [4000]);
        await network.provider.send("evm_mine");
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker1Amount, EPSILON);
        expect(claimableReward[1]).to.be.closeTo(expectedLocker2Amount, EPSILON);
        expect(claimableReward[2]).to.be.closeTo(expectedLocker3Amount, EPSILON);
        claimableReward = await lockerClaimableReward(1, 1);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker2Amount, EPSILON);
        claimableReward = await lockerClaimableReward(2, 2);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker3Amount, EPSILON);
        claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(3);
        expect(claimableRewardCounts[1]).to.be.equal(3);
        expect(claimableRewardCounts[2]).to.be.equal(1);

        let currentBones = await bonesBalance(this.wrappedSslp0)
        await lockerClaimReward(0, 0, 1);
        expect(await bonesBalance(this.wrappedSslp0)).to.be.equal(currentBones.add(lockedBonesReward(block1, block2)))
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.closeTo(expectedLocker1Amount.sub(lockedBonesReward(block1, block2)), EPSILON);
        expect(claimableReward[1]).to.be.closeTo(expectedLocker2Amount, EPSILON);
        expect(claimableReward[2]).to.be.closeTo(expectedLocker3Amount, EPSILON);
        claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(2);
        expect(claimableRewardCounts[1]).to.be.equal(3);
        expect(claimableRewardCounts[2]).to.be.equal(1);

        currentBones = await bonesBalance(this.wrappedSslp0)
        await lockerClaimReward(0, 2, 2);
        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(
            currentBones
                .add(lockedBonesReward(block2, block3))
                .add(lockedBonesReward(block3, block4))
                .add(lockedBonesReward(block4, block5))
                .add(lockedBonesReward(block5, block6))
                .add(lockedBonesReward(block7, block8)),
            EPSILON
        )
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.equal(ether('0'));
        expect(claimableReward[1]).to.be.closeTo(lockedBonesReward(block6, block7), EPSILON);
        expect(claimableReward[2]).to.be.equal(ether('0'));
        claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(0);
        expect(claimableRewardCounts[1]).to.be.equal(1);
        expect(claimableRewardCounts[2]).to.be.equal(0);

        currentBones = await bonesBalance(this.wrappedSslp0)
        await lockerClaimReward(1, 2, 5);
        expect(await bonesBalance(this.wrappedSslp0)).to.be.closeTo(
            currentBones
                .add(lockedBonesReward(block6, block7)),
            EPSILON
        )
        claimableReward = await lockerClaimableReward(0, 2);
        expect(claimableReward[0]).to.be.equal(ether('0'));
        expect(claimableReward[1]).to.be.equal(ether('0'));
        expect(claimableReward[2]).to.be.equal(ether('0'));
        claimableRewardCounts = await getBoneLockerRewardsCount(0, 2);
        expect(claimableRewardCounts[0]).to.be.equal(0);
        expect(claimableRewardCounts[1]).to.be.equal(0);
        expect(claimableRewardCounts[2]).to.be.equal(0);
    })

    it('handle change of lptopken in topdog', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, ether('1'));

        context.migratorShib = await deployContract("MigratorShib_Mock");
        await context.migratorShib.setNewToken(context.sslpToken1.address);
        await context.sslpToken1.transfer(context.migratorShib.address, ether('100'));
        await context.topDog.setMigrator(context.migratorShib.address);

        await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
        expect(await this.sslpToken1.balanceOf(this.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(lockAmount, "old lp tokens sent to topdog");
        expect(await this.sslpToken1.balanceOf(this.topDog.address)).to.be.equal(ether('0'), "no topdog balance in new lp token");

        expect(await context.wrappedSslp0.getUnderlyingToken()).to.be.equal(context.sslpToken0.address);
        await context.topDog.connect(this.user3).migrate(0); // anyone can migrate
        expect(await context.wrappedSslp0.getUnderlyingToken()).to.be.equal(context.sslpToken1.address);

        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "rest of old lp tokens");
        expect(await this.sslpToken1.balanceOf(this.user1.address)).to.be.equal(ether('0'), "no user balance in new lp token");
        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(lockAmount, "old lp tokens sent to topdog");
        expect(await this.sslpToken1.balanceOf(this.topDog.address)).to.be.equal(lockAmount, "topdog balance in new lp tokens");

        await unwrapAndExit(this.user1, lockAmount, usdpAmount);

        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "nothing returned in old lp tokens");
        expect(await this.sslpToken1.balanceOf(this.user1.address)).to.be.equal(lockAmount, "but returned in new lp tokens");
        expect(await this.sslpToken0.balanceOf(this.topDog.address)).to.be.equal(lockAmount, "old lp tokens didn't use");
        expect(await this.sslpToken1.balanceOf(this.topDog.address)).to.be.equal(ether('0'), "no new lp tokens left in topdog");

    })

    it('exit without unwrap', async function () {
        const lockAmount = ether('0.4');
        const usdpAmount = ether('0.2');

        await prepareUserForJoin(this.user1, ether('1'));

        await wrapAndJoin(this.user1, lockAmount, usdpAmount);
        await context.cdpManager.connect(this.user1).exit(context.wrappedSslp0.address, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('0.6'), "nothing returned in lp tokens");
        expect(await this.wrappedSslp0.balanceOf(this.user1.address)).to.be.equal(lockAmount, "but returned in new wrapped tokens");

        // rescue of tokens - rejoin and unwrapAndExit
        await context.cdpManager.connect(this.user1).join(context.wrappedSslp0.address, lockAmount, usdpAmount);
        await unwrapAndExit(this.user1, lockAmount, usdpAmount);
        expect(await this.sslpToken0.balanceOf(this.user1.address)).to.be.equal(ether('1'), "everything returned in lp tokens");
        expect(await this.wrappedSslp0.balanceOf(this.user1.address)).to.be.equal(0, "zero wraped tokens");
    })
});
