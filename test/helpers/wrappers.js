const {ether} = require("openzeppelin-test-helpers");
module.exports = function(context, mode) {

	const addUsdpAndApproveBorrowFee = async (vaultManager, approveUSDP, from) => {
		if (approveUSDP === -1) {
			// default case, user approved enough tokens
			await context.usdp.approve(vaultManager.address, ether('1000'), {from});
		} else {
			// approve exactly as requested
			await context.usdp.approve(vaultManager.address, approveUSDP, {from});
		}
	}

	const simpleWrapper = {
		join: async (asset, mainAmount, usdpAmount, { noApprove, approveUSDP = -1, from = context.deployer } = {}) => {
			if (!noApprove) {
				await asset.approve(context.vault.address, mainAmount, {from});
			}

			await addUsdpAndApproveBorrowFee(context.vaultManager, approveUSDP, from);

			return context.vaultManager.join(
				asset.address,
				mainAmount, // main
				usdpAmount,	// USDP
				{ from }
			);
		},
		joinEth: async (mainAmount, usdpAmount, { noApprove, approveUSDP = -1, from = context.deployer } = {}) => {
			const debt = await context.vault.debts(context.weth.address, context.deployer)
			await context.usdp.approve(context.vault.address, debt)
			if (!noApprove) {
				await context.weth.approve(context.vault.address, mainAmount, {from});
			}

			await addUsdpAndApproveBorrowFee(context.vaultManager, approveUSDP, from);

			return context.vaultManager.join_Eth(
				usdpAmount,	// USDP
				{ value: mainAmount }
			);
		},
		exit: async (asset, mainAmount, usdpAmount) => {
			if (+usdpAmount > 0) {
				await context.usdp.approve(context.vault.address, usdpAmount)
			}
			return context.vaultManager.exit(
				asset.address,
				mainAmount, // main
				usdpAmount,	// USDP
			);
		},
		exitTarget: async (asset, mainAmount, repayment) => {
			if (+repayment > 0) {
				await context.usdp.approve(context.vault.address, repayment)
			}
			return context.vaultManager.exit_targetRepayment(
				asset.address,
				mainAmount, // main
				repayment,	// USDP
			);
		},
		exitEth: async (mainAmount, usdpAmount) => {
			const debt = await context.vault.debts(context.weth.address, context.deployer)
			await context.usdp.approve(context.vault.address, debt)
			await context.weth.approve(context.vaultManager.address, mainAmount);
			return context.vaultManager.exit_Eth(
				mainAmount, // main
				usdpAmount,	// USDP
			);
		},
		triggerLiquidation: (asset, user, from = context.deployer) => {
			return context.vaultManager.triggerLiquidation(
				asset.address,
				user,
				{ from }
			);
		},
		repayAllAndWithdraw: async (main, user) => {
			const totalDebt = await context.vault.getTotalDebt(main.address, user);

			// mint usdp to cover initial borrow fee
			await context.usdp.tests_mint(user, context.utils.calcBorrowFee(totalDebt));

			await context.usdp.approve(context.vault.address, totalDebt);
			const mainAmount = await context.vault.collaterals(main.address, user);
			return context.vaultManager.exit(main.address, mainAmount, context.utils.MAX_UINT);
		},
	}

	const keydonixWrapper = {
		join: async (main, mainAmount, usdpAmount, { noApprove, approveUSDP = -1 } = {}) => {
			if (!noApprove) {
				await main.approve(context.vault.address, mainAmount);
			}

			await addUsdpAndApproveBorrowFee(context.vaultManagerKeydonix, approveUSDP, context.deployer);

			return context.vaultManagerKeydonix.join(
				main.address,
				mainAmount, // main
				usdpAmount,	// USDP
				['0x', '0x', '0x', '0x'], // main price proof
			)
		},
		exit: async (main, mainAmount, usdpAmount) => {
			return context.vaultManagerKeydonix.exit(
				main.address,
				mainAmount, // main
				usdpAmount,	// USDP
				['0x', '0x', '0x', '0x'], // main price proof
			);
		},
		triggerLiquidation: (main, user, from = context.deployer) => {
			return context.vaultManagerKeydonix.triggerLiquidation(
				main.address,
				user,
				['0x', '0x', '0x', '0x'], // main price proof
				{ from }
			);
		},
		repayAllAndWithdraw: async (main, user) => {
			const totalDebt = await context.vault.getTotalDebt(main.address, user);

			// mint usdp to cover initial borrow fee
			await context.usdp.tests_mint(user, context.utils.calcBorrowFee(totalDebt));

			await context.usdp.approve(context.vault.address, totalDebt);
			const mainAmount = await context.vault.collaterals(main.address, user);
			return context.vaultManagerKeydonix.exit(main.address, mainAmount, context.utils.MAX_UINT, ['0x', '0x', '0x', '0x'],);
		},
	};

	const wrappers = {
		keydonixMainAsset: keydonixWrapper,
		keydonixPoolToken: keydonixWrapper,
		uniswapKeep3rMainAsset: simpleWrapper,
		uniswapKeep3rPoolToken: simpleWrapper,
		chainlinkMainAsset: simpleWrapper,
		chainlinkPoolToken: simpleWrapper,
		sushiswapKeep3rMainAsset: simpleWrapper,
		sushiswapKeep3rPoolToken: simpleWrapper,
		bearingAssetSimple: simpleWrapper,
		curveLP: simpleWrapper,
		cyWETHsample: simpleWrapper,
		yvWETHsample: simpleWrapper,
		wstETHsample: simpleWrapper,
	}
	return wrappers[mode];
}
