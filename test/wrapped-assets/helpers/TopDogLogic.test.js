const { expect } = require("chai");
const { ethers } = require("hardhat");
const {directBonesReward, fullBonesReward, lockedBonesReward} = require("./TopDogLogic");
const {ether} = require("../../helpers/ethersUtils");

describe("TopDogLogic", function () {
    [0, 1, 3, 10].forEach(blockInterval =>
        it(`test bone reward calculation helper with interval ${blockInterval} blocks`, async function () {
            const expectedResult = {
                0: ether('0'),
                1: ether('8.25'),
                3: ether('24.75'),
                10: ether('82.5'),
            }

            expect(directBonesReward(10, 10+blockInterval)).to.be.equal(expectedResult[blockInterval]);
            expect(fullBonesReward(10, 10+blockInterval)).to.be.equal(
                directBonesReward(10, 10+blockInterval).add(lockedBonesReward(10, 10+blockInterval))
            );
        })
    );
});
