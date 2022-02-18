const {prepareCoreContracts} = require("./helpers/deploy");
const {deployContract, BN} = require("./helpers/ethersUtils");

let context;
describe("AssetsBooleanParameters", function () {

	beforeEach(async function () {
		context = this;
		[this.deployer, this.user1, this.user2, this.user3, this.manager] = await ethers.getSigners();
		await prepareCoreContracts(this)
	});
	
	it("set params in constructor", async function () {
		async function checkVals(paramsContract, user, val0, val1, val255, valAll) {
			expect(await paramsContract.get(user.address, 0)).to.be.equal(val0);
			expect(await paramsContract.get(user.address, 1)).to.be.equal(val1);
			expect(await paramsContract.get(user.address, 255)).to.be.equal(val255);
			expect(await paramsContract.getAll(user.address)).to.be.equal(valAll);
		}

		let paramsContract = await deployContract("AssetsBooleanParameters", this.vaultParameters.address, [], []);
		await checkVals(paramsContract, this.user1, false, false, false, 0);

		paramsContract = await deployContract("AssetsBooleanParameters", this.vaultParameters.address, [this.user1.address], [0]);
		await checkVals(paramsContract, this.user1, true, false, false, 1);

		paramsContract = await deployContract("AssetsBooleanParameters", this.vaultParameters.address, [this.user1.address], [1]);
		await checkVals(paramsContract, this.user1, false, true, false, 2);

		paramsContract = await deployContract("AssetsBooleanParameters", this.vaultParameters.address, [this.user1.address], [255]);
		await checkVals(paramsContract, this.user1, false, false, true, BN('2').pow('255'));

		paramsContract = await deployContract(
			"AssetsBooleanParameters", this.vaultParameters.address,
			[this.user1.address, this.user1.address, this.user2.address, this.user1.address],
			[255, 0, 1, 1]
		);
		await checkVals(paramsContract, this.user1, true, true, true, BN('2').pow('255').add(1).add(2));
		await checkVals(paramsContract, this.user2, false, true, false, 2);

		await expect(
			deployContract(
				"AssetsBooleanParameters", this.vaultParameters.address,
				[this.user1.address, this.user1.address],
				[255]
			)
		).to.be.revertedWith("ARGUMENTS_LENGTH_MISMATCH")
	})

	it("set and get", async function () {
		async function checkVals(user, val0, val1, val255, valAll) {
			expect(await context.assetsBooleanParameters.get(user.address, 0)).to.be.equal(val0);
			expect(await context.assetsBooleanParameters.get(user.address, 1)).to.be.equal(val1);
			expect(await context.assetsBooleanParameters.get(user.address, 255)).to.be.equal(val255);
			expect(await context.assetsBooleanParameters.getAll(user.address)).to.be.equal(valAll);
		}

		async function callSet(user, param, val, valAll) {
			let res = await context.assetsBooleanParameters.set(user.address, param, val);
			await expect(res).to.emit(context.assetsBooleanParameters, val ? "ValueSet" : "ValueUnset").withArgs(user.address, param, valAll);
		}

		await checkVals(this.user1, false, false, false, 0);
		await checkVals(this.user2, false, false, false, 0);

		await callSet(this.user1, 0, true, 1);
		await checkVals(this.user1, true, false, false, 1);
		await checkVals(this.user2, false, false, false, 0);

		await callSet(this.user1, 255, true, BN('2').pow('255').add(1));
		await checkVals(this.user1, true, false, true, BN('2').pow('255').add(1));
		await checkVals(this.user2, false, false, false, 0);

		await callSet(this.user2, 1, true, 2);
		await checkVals(this.user1, true, false, true, BN('2').pow('255').add(1));
		await checkVals(this.user2, false, true, false, 2);

		await callSet(this.user1, 1, true, BN('2').pow('255').add(1).add(2));
		await checkVals(this.user1, true, true, true, BN('2').pow('255').add(1).add(2));
		await checkVals(this.user2, false, true, false, 2);

		await callSet(this.user1, 0, false, BN('2').pow('255').add(2));
		await checkVals(this.user1, false, true, true, BN('2').pow('255').add(2));
		await checkVals(this.user2, false, true, false, 2);

		await callSet(this.user1, 1, false, BN('2').pow('255'));
		await checkVals(this.user1, false, false, true, BN('2').pow('255'));
		await checkVals(this.user2, false, true, false, 2);

		await callSet(this.user1, 255, false, 0);
		await checkVals(this.user1, false, false, false, 0);
		await checkVals(this.user2, false, true, false, 2);

		await callSet(this.user2, 1, false, 0);
		await checkVals(this.user1, false, false, false, 0);
		await checkVals(this.user2, false, false, false, 0);
	});

	it("set errors", async function () {
		await expect(
			context.assetsBooleanParameters.set('0x0000000000000000000000000000000000000000', 1, true)
		).to.be.revertedWith("ZERO_ADDRESS");

		await expect(
			context.assetsBooleanParameters.connect(this.user1).set(this.user1.address, 1, true)
		).to.be.revertedWith("AUTH_FAILED")
	})

	it("only 255 values", async function () {
		await expect(
			this.assetsBooleanParameters.set(this.user1.address, 256, true)
		).to.be.reverted;
	})

});
