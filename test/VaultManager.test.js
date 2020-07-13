const {
	constants,
	expectEvent,
	expectRevert,
	time,
	ether
} = require('openzeppelin-test-helpers');
const balance = require('./helpers/balances');
const BN = web3.utils.BN;
const { expect } = require('chai');

const { ZERO_ADDRESS } = constants;

const Classic = artifacts.require('Logic');
const Settings = artifacts.require('TimviSettings');
const Token = artifacts.require('TimviToken');
const Oracle = artifacts.require('OracleContractMock');
const BondService = artifacts.require('BondService');

contract('BondService', function([
	_,
	emitter,
	owner,
	anotherAccount
]) {
	// deploy & initial settings
	beforeEach(async function() {
		this.settings = await Settings.new();
		this.logic = await Classic.new(this.settings.address);
		this.token = await Token.new(this.settings.address);
		this.oracle = await Oracle.new();
		await this.settings.setTmvAddress(this.token.address);
		await this.settings.setOracleAddress(this.oracle.address);
		const receipt = await this.settings.setContractManager(
			this.logic.address
		);
		this.service = await BondService.new(this.settings.address);

		const tx = await web3.eth.getTransaction(receipt.tx);
		this.gasPrice = new BN(tx.gasPrice);
	});

	describe('Apply leverage creating', function() {
		const deposit = ether('1');
		const percent = new BN('150000');
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		describe('reverts', function() {
			it('when deposit is very small', async function() {
				const deposit = ether('1').div(new BN(20));

				await expectRevert(
					this.service.leverage(percent, expiration, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Too small funds'
				);
			});
			it('when specified percent is higher than available', async function() {
				const percent = 115900;

				await expectRevert(
					this.service.leverage(percent, expiration, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Collateralization is not enough'
				);
			});
			it('when year fee is higher than 10%', async function() {
				const yearFee = new BN('10001');

				await expectRevert(
					this.service.leverage(percent, expiration, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Fee out of range'
				);
			});
			it('when expiration out of range', async function() {
				const expiration1 = new BN(24 * 60 * 60 - 1);
				const expiration2 = new BN(365 * 24 * 60 * 60 + 1);

				await expectRevert(
					this.service.leverage(percent, expiration1, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Expiration out of range'
				);
				await expectRevert(
					this.service.leverage(percent, expiration2, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Expiration out of range'
				);
			});
		});
		describe('success', function() {
			it('creates record about new Bond', async function() {
				await this.service.leverage(percent, expiration, yearFee, {
					from: emitter,
					value: deposit
				});
				const bond = await this.service.bonds.call(0);
				expect(bond[0]).to.have.string(emitter);
				expect(bond[1]).to.have.string(ZERO_ADDRESS);
				expect(bond[2]).to.be.bignumber.equal(deposit);
				expect(bond[3]).to.be.bignumber.equal(percent);
				expect(bond[4]).to.be.bignumber.equal(new BN(0));
				expect(bond[5]).to.be.bignumber.equal(expiration);
				expect(bond[6]).to.be.bignumber.equal(yearFee);
				expect(bond[7]).to.be.bignumber.equal(new BN(0));
				expect(bond[8]).to.be.bignumber.equal(new BN(0));
				expect(bond[9]).to.be.bignumber.equal(new BN(0));
			});
			it('increases the contract balance', async function() {
				const tx = this.service.leverage(
					percent,
					expiration,
					yearFee,
					{ value: deposit }
				);
				expect(
					await balance.difference(this.service.address, tx)
				).to.be.bignumber.equal(deposit);
			});
			it('emits a create event', async function() {
				const { logs } = await this.service.leverage(
					percent,
					expiration,
					yearFee,
					{ from: emitter, value: deposit }
				);
				expectEvent.inLogs(logs, 'BondCreated', {
					id: new BN(0),
					who: emitter,
					deposit: deposit,
					percent: percent
				});
			});
		});
	});

	describe('Apply exchange creating', function() {
		const deposit = ether('1');
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		describe('reverts', function() {
			it('when deposit is very small', async function() {
				const deposit = ether('1').div(new BN(20));

				await expectRevert(
					this.service.exchange(expiration, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Too small funds'
				);
			});
			it('when year fee is higher than 10%', async function() {
				const yearFee = new BN('10001');

				await expectRevert(
					this.service.exchange(expiration, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Fee out of range'
				);
			});
			it('when expiration out of range', async function() {
				const expiration1 = new BN(24 * 60 * 60 - 1);
				const expiration2 = new BN(365 * 24 * 60 * 60 + 1);

				await expectRevert(
					this.service.exchange(expiration1, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Expiration out of range'
				);
				await expectRevert(
					this.service.exchange(expiration2, yearFee, {
						from: emitter,
						value: deposit
					}),
					'Expiration out of range'
				);
			});
		});
		describe('success', function() {
			it('creates record about new Bond', async function() {
				await this.service.exchange(expiration, yearFee, {
					from: emitter,
					value: deposit
				});
				const bond = await this.service.bonds(0);
				expect(bond[0]).to.have.string(ZERO_ADDRESS);
				expect(bond[1]).to.have.string(emitter);
				expect(bond[2]).to.be.bignumber.equal(deposit);
				expect(bond[3]).to.be.bignumber.equal(new BN(0));
				expect(bond[4]).to.be.bignumber.equal(new BN(0));
				expect(bond[5]).to.be.bignumber.equal(expiration);
				expect(bond[6]).to.be.bignumber.equal(yearFee);
				expect(bond[7]).to.be.bignumber.equal(new BN(0));
				expect(bond[8]).to.be.bignumber.equal(new BN(0));
				expect(bond[9]).to.be.bignumber.equal(new BN(0));
			});
			it('increases the contract balance', async function() {
				const tx = this.service.exchange(expiration, yearFee, {
					value: deposit
				});
				expect(
					await balance.difference(this.service.address, tx)
				).to.be.bignumber.equal(deposit);
			});
			it('emits a create event', async function() {
				const { logs } = await this.service.exchange(
					expiration,
					yearFee,
					{ from: emitter, value: deposit }
				);
				expectEvent.inLogs(logs, 'BondCreated', {
					id: new BN(0),
					who: emitter,
					deposit: deposit,
					percent: new BN(0)
				});
			});
		});
	});

	describe('Changing bond', function() {
		const deposit = ether('1');
		const newDeposit = ether('2');
		const deltaDeposit = newDeposit.sub(deposit);
		const percent = new BN('150000');
		const yearFee = new BN('9000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);

		beforeEach(async function() {
			const percent = new BN('150232');
			const yearFee = new BN('10000');
			const expiration = new BN(60 * 24 * 60 * 60);
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
		});

		describe('reverts', function() {
			it('when deposit is very small', async function() {
				const newDeposit = ether('1').div(new BN(20));

				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration,
						yearFee,
						{ from: emitter, value: deltaDeposit }
					),
					'Too small funds'
				);
			});
			it("when deposit isn't matched", async function() {
				const deltaDeposit = ether('1').div(new BN(2));

				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration,
						yearFee,
						{ from: emitter, value: deltaDeposit.sub(new BN(1)) }
					),
					'Incorrect value'
				);
				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration,
						yearFee,
						{ from: emitter, value: deltaDeposit.add(new BN(1)) }
					),
					'Incorrect value'
				);
			});
			it('when specified percent is higher than available', async function() {
				const percent = 115900;

				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration,
						yearFee,
						{ from: emitter, value: deltaDeposit }
					),
					'Collateralization is not enough'
				);
			});
			it('when year fee is higher than 10%', async function() {
				const yearFee = new BN('10001');

				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration,
						yearFee,
						{ from: emitter, value: deltaDeposit }
					),
					'Fee out of range'
				);
			});
			it('when expiration out of range', async function() {
				const expiration1 = new BN(24 * 60 * 60 - 1);
				const expiration2 = new BN(365 * 24 * 60 * 60 + 1);

				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration1,
						yearFee,
						{ from: emitter, value: deltaDeposit }
					),
					'Expiration out of range'
				);
				await expectRevert(
					this.service.changeEmitter(
						bondId,
						newDeposit,
						percent,
						expiration2,
						yearFee,
						{ from: emitter, value: deltaDeposit }
					),
					'Expiration out of range'
				);
			});
			it('changes by non-owner', async function() {
				await this.service.exchange(expiration, yearFee, {
					from: owner,
					value: deposit
				});
				const bondId = new BN(1);
				await expectRevert(
					this.service.changeOwner(
						bondId,
						newDeposit,
						expiration,
						yearFee,
						{ from: anotherAccount, value: deltaDeposit }
					),
					'You are not the owner'
				);
			});
		});
		describe('success', function() {
			it('updates record about the Bond', async function() {
				await this.service.changeEmitter(
					bondId,
					newDeposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter, value: deltaDeposit }
				);
				const bond = await this.service.bonds(0);
				expect(bond[0]).to.have.string(emitter);
				expect(bond[1]).to.have.string(ZERO_ADDRESS);
				expect(bond[2]).to.be.bignumber.equal(newDeposit);
				expect(bond[3]).to.be.bignumber.equal(percent);
				expect(bond[4]).to.be.bignumber.equal(new BN(0));
				expect(bond[5]).to.be.bignumber.equal(expiration);
				expect(bond[6]).to.be.bignumber.equal(yearFee);
				expect(bond[7]).to.be.bignumber.equal(new BN(0));
				expect(bond[8]).to.be.bignumber.equal(new BN(0));
				expect(bond[9]).to.be.bignumber.equal(new BN(0));
			});
			it('not changes old values', async function() {
				const percent = new BN('150232');
				const yearFee = new BN(10000);
				const expiration = new BN(60 * 24 * 60 * 60);
				await this.service.changeEmitter(
					bondId,
					deposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter }
				);
				const bond = await this.service.bonds(0);
				expect(bond[0]).to.have.string(emitter);
				expect(bond[1]).to.have.string(ZERO_ADDRESS);
				expect(bond[2]).to.be.bignumber.equal(deposit);
				expect(bond[3]).to.be.bignumber.equal(percent);
				expect(bond[4]).to.be.bignumber.equal(new BN(0));
				expect(bond[5]).to.be.bignumber.equal(expiration);
				expect(bond[6]).to.be.bignumber.equal(yearFee);
				expect(bond[7]).to.be.bignumber.equal(new BN(0));
				expect(bond[8]).to.be.bignumber.equal(new BN(0));
				expect(bond[9]).to.be.bignumber.equal(new BN(0));
			});
			it('when old deposit is higher than new', async function() {
				const deposit = ether('2');
				const newDeposit = ether('1');
				await this.service.leverage(percent, expiration, yearFee, {
					from: emitter,
					value: deposit
				});
				const bondId = 1;
				const tx = this.service.changeEmitter(
					bondId,
					newDeposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter }
				);
				const diff = await balance.differenceExcludeGas(
					emitter,
					tx,
					this.gasPrice
				);
				expect(diff).to.be.bignumber.equal(deltaDeposit);
			});
			it('changes by owner', async function() {
				await this.service.exchange(expiration, yearFee, {
					from: owner,
					value: deposit
				});
				const bondId = new BN(1);
				await this.service.changeOwner(
					bondId,
					newDeposit,
					expiration,
					yearFee,
					{ from: owner, value: deltaDeposit }
				);
			});
			it('increases the contract balance', async function() {
				const tx = this.service.changeEmitter(
					bondId,
					newDeposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter, value: deposit }
				);
				expect(
					await balance.difference(this.service.address, tx)
				).to.be.bignumber.equal(deltaDeposit);
			});
			it('reduces the user balance', async function() {
				const tx = this.service.changeEmitter(
					bondId,
					newDeposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter, value: deposit }
				);
				expect(
					await balance.differenceExcludeGas(
						emitter,
						tx,
						this.gasPrice
					)
				).to.be.bignumber.equal(deltaDeposit);
			});
			it('emits a change event', async function() {
				const { logs } = await this.service.changeEmitter(
					bondId,
					newDeposit,
					percent,
					expiration,
					yearFee,
					{ from: emitter, value: deposit }
				);
				expectEvent.inLogs(logs, 'BondChanged', {
					id: new BN(0),
					deposit: newDeposit,
					percent: percent,
					expiration: expiration,
					yearFee: yearFee
				});
			});
		});
	});
	describe('Closing leverage', function() {
		const deposit = ether('1');
		const percent = new BN('150000');
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);

		beforeEach(async function() {
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
		});

		it('reverts closing by alien', async function() {
			await expectRevert(
				this.service.close(new BN(0), { from: owner }),
				'You are not the single owner'
			);
		});
		it('removes a record about Bond', async function() {
			await this.service.close(bondId, { from: emitter });
			const bond = await this.service.bonds(0);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('increases ETH user balance', async function() {
			const tx = this.service.close(bondId, { from: emitter });
			const diff = await balance.differenceExcludeGas(
				emitter,
				tx,
				this.gasPrice
			);
			expect(diff).to.be.bignumber.equal(deposit);
		});
		it('reduces ETH contract balance', async function() {
			const tx = this.service.close(bondId, { from: emitter });
			expect(
				await balance.difference(this.service.address, tx)
			).to.be.bignumber.equal(deposit);
		});
		it('emits a close event', async function() {
			const { logs } = await this.service.close(0, { from: emitter });
			expectEvent.inLogs(logs, 'BondClosed', {
				id: new BN(0)
			});
		});
	});
	describe('Closing exchange', function() {
		const deposit = ether('1');
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);

		beforeEach(async function() {
			await this.service.exchange(expiration, yearFee, {
				from: emitter,
				value: deposit
			});
		});

		it('reverts closing by alien', async function() {
			await expectRevert(
				this.service.close(new BN(0), { from: owner }),
				'You are not the single owner'
			);
		});
		it('removes a record about Bond', async function() {
			await this.service.close(bondId, { from: emitter });
			const bond = await this.service.bonds(0);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('increases ETH user balance', async function() {
			const tx = this.service.close(bondId, { from: emitter });
			const diff = await balance.differenceExcludeGas(
				emitter,
				tx,
				this.gasPrice
			);
			expect(diff).to.be.bignumber.equal(deposit);
		});
		it('reduces ETH contract balance', async function() {
			const tx = this.service.close(bondId, { from: emitter });
			expect(
				await balance.difference(this.service.address, tx)
			).to.be.bignumber.equal(deposit);
		});
		it('emits a close event', async function() {
			const { logs } = await this.service.close(0, { from: emitter });
			expectEvent.inLogs(logs, 'BondClosed', {
				id: new BN(0)
			});
		});
	});
	describe('Matching leverage', function() {
		const deposit = new BN(ether('1').toString());
		const percent = new BN(115217);
		const matchDepo = deposit.mul(new BN(100000)).div(percent);
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);
		let tmv;

		beforeEach(async function() {
			await this.logic.create(1, {
				from: emitter,
				value: deposit.mul(new BN(10))
			});
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
		});

		it('reverts non-existent bid', async function() {
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			const bondId = 1;
			await this.service.close(bondId, { from: emitter });

			await expectRevert(
				this.service.takeEmitRequest(bondId, {
					value: matchDepo,
					from: owner
				}),
				"The bond isn't an emit request"
			);
		});
		it("returns when attached value isn't expected", async function() {
			await expectRevert(
				this.service.takeEmitRequest(bondId, {
					value: matchDepo.add(new BN(1)),
					from: owner
				}),
				'Incorrect ETH value'
			);
			await expectRevert(
				this.service.takeEmitRequest(bondId, {
					value: matchDepo.sub(new BN(1)),
					from: owner
				}),
				'Incorrect ETH value'
			);
		});
		it('returns when the percentage has become impossible', async function() {
			await this.logic.withdrawTmvMax(new BN(0), { from: emitter });

			await expectRevert(
				this.service.takeEmitRequest(bondId, {
					value: matchDepo,
					from: owner
				}),
				'Token amount is more than available'
			); // reverts in ClassicCapitalized
		});
		it('mints 721 token to service contract', async function() {
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			const tBoxId = new BN(1);
			const apprOrOwnr = await this.logic.isApprovedOrOwner.call(
				this.service.address,
				tBoxId
			);

			expect(apprOrOwnr).to.be.true;
		});
		it('transfers mathcing ETH to emitter', async function() {
			const tx = this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			const diff = await balance.difference(emitter, tx);
			const fee = matchDepo.mul(new BN(5)).div(new BN(1000)); // 0.5%

			expect(diff).to.be.bignumber.equal(matchDepo.sub(fee));
		});
		it('mints TMV equivalent to matcher', async function() {
			const balanceBefore = await this.token.balanceOf(owner);
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			const rate = new BN(10000000);
			const precision = new BN(100000);
			tmv = matchDepo.mul(rate).div(precision);
			const balanceAfter = await this.token.balanceOf(owner);

			expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(
				tmv
			);
		});
		it('updates record about matched bond', async function() {
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			const timestamp = await time.latest();
			const bond = await this.service.bonds(bondId);

			expect(bond[0]).to.have.string(emitter);
			expect(bond[1]).to.have.string(owner);
			expect(bond[2]).to.be.bignumber.equal(deposit);
			expect(bond[3]).to.be.bignumber.equal(percent);
			expect(bond[4]).to.be.bignumber.equal(tmv);
			expect(bond[5]).to.be.bignumber.equal(
				expiration.add(timestamp)
			);
			expect(bond[6]).to.be.bignumber.equal(yearFee);
			expect(bond[7]).to.be.bignumber.equal(new BN(10000));
			expect(bond[8]).to.be.bignumber.equal(new BN(1));
			expect(bond[9]).to.be.bignumber.equal(timestamp);
		});
		it('emits the matching event', async function() {
			const { logs } = await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});

			expectEvent.inLogs(logs, 'BondMatched', {
				id: new BN(0),
				tBox: new BN(1)
			});
		});
	});
	describe('Matching exchange', function() {
		const deposit = ether('1');
		const matchDepo = deposit.mul(new BN(2));
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);
		let tmv;

		beforeEach(async function() {
			await this.logic.create(1, {
				from: owner,
				value: deposit.mul(new BN(10))
			});
			await this.service.exchange(expiration, yearFee, {
				from: owner,
				value: deposit
			});
		});

		it('reverts non-existent bid', async function() {
			await this.service.exchange(expiration, yearFee, {
				from: owner,
				value: deposit
			});
			const bondId = 1;
			await this.service.close(bondId, { from: owner });

			await expectRevert(
				this.service.takeBuyRequest(bondId, {
					value: matchDepo,
					from: emitter
				}),
				"The bond isn't an buy request"
			);
		});
		it('returns when attached value is less than possible', async function() {
			await expectRevert(
				this.service.takeBuyRequest(bondId, {
					value: matchDepo.div(new BN(2)),
					from: emitter
				}),
				'Token amount is more than available'
			);
		});
		it('mints 721 token to service contract', async function() {
			await this.service.takeBuyRequest(bondId, {
				value: matchDepo,
				from: emitter
			});
			const tBoxId = 1;
			const apprOrOwnr = await this.logic.isApprovedOrOwner.call(
				this.service.address,
				tBoxId
			);

			expect(apprOrOwnr).to.be.true;
		});
		it('transfers packed ETH to matcher', async function() {
			const tx = this.service.takeBuyRequest(bondId, {
				value: matchDepo,
				from: emitter
			});
			const diff = await balance.differenceExcludeGas(
				emitter,
				tx,
				this.gasPrice
			);
			const fee = deposit.mul(new BN(5)).div(new BN(1000)); // 0.5%
			const calculatedDiff = matchDepo.sub(deposit).add(fee);

			expect(diff).to.be.bignumber.equal(calculatedDiff);
		});
		it('mints TMV equivalent to owner', async function() {
			const balanceBefore = await this.token.balanceOf(owner);
			await this.service.takeBuyRequest(bondId, {
				value: matchDepo,
				from: emitter
			});
			const rate = new BN(10000000);
			const precision = new BN(100000);
			tmv = deposit.mul(rate).div(precision);
			const balanceAfter = await this.token.balanceOf(owner);

			expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(
				tmv
			);
		});
		it('updates record about matched bond', async function() {
			await this.service.takeBuyRequest(bondId, {
				value: matchDepo,
				from: emitter
			});
			const timestamp = await time.latest();
			const bond = await this.service.bonds(bondId);

			expect(bond[0]).to.have.string(emitter);
			expect(bond[1]).to.have.string(owner);
			expect(bond[2]).to.be.bignumber.equal(deposit);
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(tmv);
			expect(bond[5]).to.be.bignumber.equal(
				expiration.add(timestamp)
			);
			expect(bond[6]).to.be.bignumber.equal(yearFee);
			expect(bond[7]).to.be.bignumber.equal(new BN(10000));
			expect(bond[8]).to.be.bignumber.equal(new BN(1));
			expect(bond[9]).to.be.bignumber.equal(timestamp);
		});
		it('emits the matching event', async function() {
			const { logs } = await this.service.takeBuyRequest(bondId, {
				value: matchDepo,
				from: emitter
			});

			expectEvent.inLogs(logs, 'BondMatched', {
				id: new BN(0),
				tBox: new BN(1)
			});
		});
	});
	describe('Finishing', function() {
		const deposit = ether('1');
		const percent = new BN(155217);
		const matchDepo = deposit.mul(new BN(100000)).div(percent);
		const yearFee = new BN('10000');
		const divivder = new BN('100000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);
		let tmv, commission, sysCom, createdAt;

		beforeEach(async function() {
			const rate = new BN(10000000);
			const precision = new BN(100000);
			tmv = matchDepo.mul(rate).div(precision);
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			createdAt = await time.latest();
			await this.token.transfer(emitter, tmv, { from: owner });
			await this.logic.create(1000, {
				from: emitter,
				value: deposit.mul(new BN(10))
			});
			await this.logic.withdrawTmvMax(1, { from: emitter });
			await this.token.approve(
				this.service.address,
				constants.MAX_INT256,
				{ from: emitter }
			);
		});

		it('reverts finishing from alien', async function() {
			await expectRevert(
				this.service.finish(bondId, { from: anotherAccount }),
				'You are not the emitter'
			);
		});

		it('reverts expired bond', async function() {
			await time.increase(expiration);
			await expectRevert(
				this.service.finish(bondId, { from: emitter }),
				'Bond expired'
			);
		});
		it('reverts when approved token amount is less than need to close', async function() {
			await this.token.decreaseAllowance(
				this.service.address,
				constants.MAX_INT256,
				{ from: emitter }
			);
			await expectRevert.unspecified(
				this.service.finish(bondId, { from: emitter })
			);
		});
		it('reverts when approved token amount is less than need to pay commission', async function() {
			await time.increase(expiration.div(new BN(2)));
			const secondsPast = expiration.div(new BN(2));
			const year = new BN(365 * 24 * 60 * 60);
			commission = tmv
				.mul(secondsPast)
				.mul(yearFee)
				.div(year)
				.div(divivder);
			sysCom = commission.mul(new BN('10000')).div(divivder);
			await this.token.approve(
				this.service.address,
				tmv.add(sysCom),
				{ from: emitter }
			);
			await expectRevert.unspecified(
				this.service.finish(bondId, { from: emitter })
			);
		});
		it("removes bond when tbox doesn't exist", async function() {
			await this.oracle.setPrice(7000000);
			await this.logic.create(0, {
				from: anotherAccount,
				value: deposit.mul(new BN(10))
			});
			await this.logic.withdrawTmvMax(2, { from: anotherAccount });

			await this.logic.capitalizeMax(0, { from: anotherAccount });
			await this.oracle.setPrice(6500000);

			await this.logic.capitalizeMax(0, { from: anotherAccount });
			await this.logic.closeDust(0, { from: anotherAccount });

			await this.service.finish(bondId, { from: emitter });

			const bond = await this.service.bonds(bondId);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('removes record about TBox', async function() {
			await time.increase(new BN(100));
			await this.service.finish(bondId, { from: emitter });
			const tBox = await this.logic.boxes(0);
			expect(tBox[0]).to.be.bignumber.equal(new BN(0));
			expect(tBox[1]).to.be.bignumber.equal(new BN(0));
		});
		it('0 commission', async function() {
			await this.service.setOwnerFee(0);
			const bondId = 1;

			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});

			await this.logic.addTmv(2, tmv, { from: emitter });

			await this.service.finish(bondId, { from: emitter });
		});
		it('removes record about Bond', async function() {
			await this.service.finish(bondId, { from: emitter });

			const bond = await this.service.bonds(bondId);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('success finishes after past time', async function() {
			await time.increase(expiration.div(new BN(2)));
			const secondsPast = expiration.div(new BN(2));
			const year = new BN(365 * 24 * 60 * 60);
			commission = tmv
				.mul(secondsPast)
				.mul(yearFee)
				.div(year)
				.div(divivder);
			sysCom = commission.mul(new BN('10000')).div(divivder);
			await this.service.finish(bondId, { from: emitter });
			// console.log((await this.token.balanceOf(emitter)).sub(new BN('68450026049437784229')).toString())
		});
		it('sends ETH to emitter', async function() {
			const tx = this.service.finish(bondId, { from: emitter });
			const diff = await balance.differenceExcludeGas(
				emitter,
				tx,
				this.gasPrice
			);

			expect(diff).to.be.bignumber.equal(deposit);
		});
		it('emits a finish event', async function() {
			const { logs } = await this.service.finish(bondId, {
				from: emitter
			});

			expectEvent.inLogs(logs, 'BondFinished', {
				id: new BN(0)
			});
		});
		it('commission stays on the contract', async function() {
			await time.increase(expiration.div(new BN(2)));

			const balanceBefore = await this.token.balanceOf(
				this.service.address
			);

			await this.service.finish(bondId, { from: emitter });

			const finishTime = await time.latest();
			const secondsPast = finishTime.sub(createdAt);
			const year = new BN(365 * 24 * 60 * 60);
			commission = tmv
				.mul(secondsPast)
				.mul(yearFee)
				.div(year)
				.div(divivder);
			sysCom = commission.mul(new BN('10000')).div(divivder);

			const balanceAfter = await this.token.balanceOf(
				this.service.address
			);

			expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(
				sysCom
			);
		});
		it('sends year fee to owner', async function() {
			await time.increase(expiration.div(new BN(2)));

			const balanceBefore = await this.token.balanceOf(owner);

			await this.service.finish(bondId, { from: emitter });

			const finishTime = await time.latest();
			const secondsPast = finishTime.sub(createdAt);
			const year = new BN(365 * 24 * 60 * 60);
			commission = tmv
				.mul(secondsPast)
				.mul(yearFee)
				.div(year)
				.div(divivder);
			sysCom = commission.mul(new BN('10000')).div(divivder);

			const balanceAfter = await this.token.balanceOf(owner);

			expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(
				commission.sub(sysCom)
			);
		});
	});
	describe('Expiration', function() {
		const deposit = ether('1');
		const percent = new BN(155217);
		const matchDepo = deposit.mul(new BN(100000)).div(percent);
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);
		let tmv, createdAt;

		beforeEach(async function() {
			const rate = new BN(10000000);
			const precision = new BN(100000);
			tmv = matchDepo.mul(rate).div(precision);
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			createdAt = await time.latest();
			await time.increase(expiration.add(new BN(1)));
		});

		it('reverts not expired bond', async function() {
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			const bondId = 1;
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});

			await expectRevert(
				this.service.expire(bondId, { from: anotherAccount }),
				"Bond hasn't expired"
			);
		});
		it('reverts not matched bond', async function() {
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			const bondId = 1;

			await expectRevert(
				this.service.expire(bondId, { from: anotherAccount }),
				"Bond isn't matched"
			);
		});
		it("removes bond when tbox doesn't exist", async function() {
			await this.oracle.setPrice(7000000);
			await this.logic.create(0, {
				from: anotherAccount,
				value: deposit.mul(new BN(10))
			});
			await this.logic.withdrawTmvMax(1, { from: anotherAccount });

			await this.logic.capitalizeMax(0, { from: anotherAccount });
			await this.oracle.setPrice(6500000);

			await this.logic.capitalizeMax(0, { from: anotherAccount });
			await this.logic.closeDust(0, { from: anotherAccount });

			await this.service.expire(bondId, { from: emitter });

			const bond = await this.service.bonds(bondId);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('transfers TBox ownership to Bond owner', async function() {
			const tBox = await this.logic.boxes(0);

			const tmv = tBox[1];

			await this.logic.create(0, {
				from: anotherAccount,
				value: deposit.mul(new BN(10))
			});
			await this.logic.withdrawTmvMax(1, { from: anotherAccount });

			await this.logic.addTmv(0, tmv, { from: anotherAccount });

			await this.service.expire(bondId, { from: emitter });
		});
		it('0-TMV TBox', async function() {
			await this.service.expire(bondId, { from: emitter });

			const apprOrOwnr = await this.logic.isApprovedOrOwner.call(
				owner,
				0
			);

			expect(apprOrOwnr).to.be.true;
		});
		it('removes bond', async function() {
			await this.service.expire(bondId, { from: emitter });

			const bond = await this.service.bonds(bondId);
			expect(bond[0]).to.have.string(ZERO_ADDRESS);
			expect(bond[1]).to.have.string(ZERO_ADDRESS);
			expect(bond[2]).to.be.bignumber.equal(new BN(0));
			expect(bond[3]).to.be.bignumber.equal(new BN(0));
			expect(bond[4]).to.be.bignumber.equal(new BN(0));
			expect(bond[5]).to.be.bignumber.equal(new BN(0));
			expect(bond[6]).to.be.bignumber.equal(new BN(0));
			expect(bond[7]).to.be.bignumber.equal(new BN(0));
			expect(bond[8]).to.be.bignumber.equal(new BN(0));
			expect(bond[9]).to.be.bignumber.equal(new BN(0));
		});
		it('emits a expiration event', async function() {
			const { logs } = await this.service.expire(bondId, {
				from: emitter
			});

			expectEvent.inLogs(logs, 'BondExpired', {
				id: new BN(0)
			});
		});
		it('expiration with 0 commission', async function() {
			await this.service.setOwnerFee(0);
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			const bondId = new BN(1);
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			await time.increase(expiration.add(new BN(1)));
			await this.service.expire(bondId, { from: owner });
		});
		it('commission stays on the contract and reduces TBox deposit', async function() {
			// let eth = new BN('32212966363220525');
			// let sys = eth.div(new BN(10));
			// let tx = this.service.expire(bondId, {from: emitter});
			// let diff = await balance.difference(this.service.address, tx);
			//
			// let tBox = await this.logic.boxes(0);
			//
			// expect(diff).to.be.bignumber.equal(sys);
			// expect(tBox[0]).to.be.bignumber.equal(deposit.sub(sys));
		});
	});
	describe('ETH fee withdrawing', function() {
		const deposit = ether('1');
		const percent = new BN(155217);
		const matchDepo = deposit.mul(new BN(100000)).div(percent);
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bidId = new BN(0);

		beforeEach(async function() {
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			await this.service.takeEmitRequest(bidId, {
				from: owner,
				value: matchDepo
			});
		});

		describe('reverts', function() {
			it('withdrawing to zero address', async function() {
				await expectRevert(
					this.service.withdrawSystemETH(ZERO_ADDRESS),
					'Zero address, be careful'
				);
			});
			it('withdrawing by non-admin', async function() {
				await expectRevert(
					this.service.withdrawSystemETH(owner, { from: owner }),
					'You have no access'
				);
			});
			it('when there are no fees nor rewards', async function() {
				await this.service.withdrawSystemETH(owner);
				await expectRevert(
					this.service.withdrawSystemETH(owner),
					'There is no available ETH'
				);
			});
		});
		describe('success', function() {
			it('zeroes fee counter', async function() {
				await this.service.withdrawSystemETH(owner);
			});
			it('reduces the contract balance', async function() {
				this.service.withdrawSystemETH(owner);
			});
			it('increases the user balance', async function() {
				this.service.withdrawSystemETH(owner);
			});
		});
	});
	describe('TMV fee withdrawing', function() {
		const deposit = ether('1');
		const percent = new BN(155217);
		const matchDepo = deposit.mul(new BN(100000)).div(percent);
		const yearFee = new BN('10000');
		const expiration = new BN(30 * 24 * 60 * 60);
		const bondId = new BN(0);
		let tmv, createdAt;

		beforeEach(async function() {
			const rate = new BN(10000000);
			const precision = new BN(100000);
			tmv = matchDepo.mul(rate).div(precision);
			await this.service.leverage(percent, expiration, yearFee, {
				from: emitter,
				value: deposit
			});
			await this.service.takeEmitRequest(bondId, {
				value: matchDepo,
				from: owner
			});
			createdAt = await time.latest();
			await this.token.transfer(emitter, tmv, { from: owner });
			await this.token.approve(
				this.service.address,
				constants.MAX_INT256,
				{ from: emitter }
			);
			await this.logic.create(0, { from: emitter, value: deposit });
			await this.logic.withdrawTmvMax(1, { from: emitter });
			await time.increase(expiration.div(new BN(2)));
			await this.service.finish(bondId, { from: emitter });
		});

		describe('reverts', function() {
			it('withdrawing to zero address', async function() {
				await expectRevert(
					this.service.reclaimERC20(this.token.address, ZERO_ADDRESS),
					'Zero address, be careful'
				);
			});
			it('withdrawing by non-admin', async function() {
				await expectRevert(
					this.service.reclaimERC20(
						this.token.address,
						anotherAccount,
						{ from: anotherAccount }
					),
					'You have no access'
				);
			});
			it('when there are no fees nor rewards', async function() {
				await this.service.reclaimERC20(
					this.token.address,
					anotherAccount
				);
				await expectRevert(
					this.service.reclaimERC20(
						this.token.address,
						anotherAccount
					),
					'There are no tokens'
				);
			});
		});
		describe('success', function() {
			it('zeroes fee counter', async function() {
				let fee = await this.token.balanceOf(this.service.address);
				expect(fee).to.be.bignumber.gt(new BN(0));
				await this.service.reclaimERC20(
					this.token.address,
					anotherAccount
				);
				fee = await this.token.balanceOf(this.service.address);
				expect(fee).to.be.bignumber.equal(new BN(0));
			});
			it('increases the user balance', async function() {
				const before = await this.token.balanceOf(anotherAccount);
				const reward = await this.token.balanceOf(
					this.service.address
				);
				await this.service.reclaimERC20(
					this.token.address,
					anotherAccount
				);
				const after = await this.token.balanceOf(anotherAccount);
				expect(after.sub(before)).to.be.bignumber.equal(reward);
			});
		});
	});
	describe('Settings the emitter commission', function() {
		const commission = new BN(10000);
		describe('reverts', function() {
			it('if setting value is higher than 10%', async function() {
				await expectRevert(
					this.service.setEmitterFee(commission.add(new BN(1))),
					'Too much'
				);
			});
			it('setting by non-admin', async function() {
				await expectRevert(
					this.service.setEmitterFee(commission, { from: owner }),
					'You have no access'
				);
			});
		});
		describe('success', function() {
			it('changes the commission', async function() {
				await this.service.setEmitterFee(commission);
				const newCom = await this.service.emitterFee();
				expect(newCom).to.be.bignumber.equal(commission);
			});
		});
	});
	describe('Settings the owner commission', function() {
		const commission = new BN(50000);
		describe('reverts', function() {
			it('if setting value is higher than 10%', async function() {
				await expectRevert(
					this.service.setOwnerFee(commission.add(new BN(1))),
					'Too much'
				);
			});
			it('setting by non-admin', async function() {
				await expectRevert(
					this.service.setOwnerFee(commission, { from: owner }),
					'You have no access'
				);
			});
		});
		describe('success', function() {
			it('changes the commission', async function() {
				await this.service.setOwnerFee(commission);
				const newCom = await this.service.ownerFee();
				expect(newCom).to.be.bignumber.equal(commission);
			});
		});
	});
	describe('Settings the min deposit amount', function() {
		const value = ether('100');
		describe('reverts', function() {
			it('if setting value is higher than 100 ether', async function() {
				await expectRevert(
					this.service.setMinEther(value.add(new BN(1))),
					'Too much'
				);
			});
			it('setting by non-admin', async function() {
				await expectRevert(
					this.service.setMinEther(value, { from: owner }),
					'You have no access'
				);
			});
		});
		describe('success', function() {
			it('changes the commission', async function() {
				await this.service.setMinEther(value);
				const newMin = await this.service.minEther();
				expect(newMin).to.be.bignumber.equal(value);
			});
		});
	});
	describe('Change the admin address', function() {
		describe('reverts', function() {
			it('zero address', async function() {
				await expectRevert(
					this.service.changeAdmin(ZERO_ADDRESS),
					'Zero address, be careful'
				);
			});
			it('setting by non-admin', async function() {
				await expectRevert(
					this.service.changeAdmin(owner, { from: owner }),
					'You have no access'
				);
			});
		});
		describe('success', function() {
			it('changes the admin address', async function() {
				await this.service.changeAdmin(owner);
				const newAdmin = await this.service.admin();
				expect(newAdmin).to.have.string(owner);
			});
		});
	});
});

// Timvi Settings Ropsten 0x4a2e3883d5f574178660998b05fc7211f5b2960e
