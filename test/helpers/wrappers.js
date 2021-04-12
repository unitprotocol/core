const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

module.exports = function(context, mode) {

	const simpleWrapper = {
		join: async (asset, mainAmount, usdpAmount, { noApprove, from = context.deployer } = {}) => {
			if (!noApprove)
				await asset.approve(context.vault.address, mainAmount, { from });
			return context.vaultManager.join(
				asset.address,
				mainAmount, // main
				usdpAmount,	// USDP
				{ from }
			);
		},
		joinEth: async (mainAmount, usdpAmount, { noApprove, from = context.deployer } = {}) => {
			const debt = await context.vault.debts(context.weth.address, context.deployer)
			await context.usdp.approve(context.vault.address, debt)
			if (!noApprove)
				await context.weth.approve(context.vault.address, mainAmount, { from });
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
			await context.usdp.approve(context.vault.address, totalDebt);
			const mainAmount = await context.vault.collaterals(main.address, user);
			return context.vaultManager.exit(main.address, mainAmount, MAX_UINT);
		},
		repay: async (main, user, usdpAmount) => {
			const totalDebt = await context.vault.getTotalDebt(main.address, user);
			await context.usdp.approve(context.vault.address, totalDebt);
			return context.vaultManager.exit(
				main.address,
				0,
				usdpAmount,
			);
		}
	}

	const keydonixWrapper = {
		join: async (asset, mainAmount, usdpAmount, { noApprove, from = context.deployer } = {}) => {
			if (!noApprove)
				await asset.approve(context.vault.address, mainAmount, { from });
			return context.vaultManager.join(
				asset.address,
				mainAmount, // main
				usdpAmount,	// USDP
				['0x', '0x', '0x', '0x'], // merkle proof mock
				{ from }
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
				['0x', '0x', '0x', '0x'], // merkle proof mock
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
				['0x', '0x', '0x', '0x'], // merkle proof mock
			);
		},
		triggerLiquidation: (asset, user, from = context.deployer) => {
			return context.vaultManager.triggerLiquidation(
				asset.address,
				user,
				['0x', '0x', '0x', '0x'], // merkle proof mock
				{ from }
			);
		},
		repayAllAndWithdraw: async (main, user) => {
			const totalDebt = await context.vault.getTotalDebt(main.address, user);
			await context.usdp.approve(context.vault.address, totalDebt);
			const mainAmount = await context.vault.collaterals(main.address, user);
			return context.vaultManager.exit(main.address, mainAmount, MAX_UINT, ['0x', '0x', '0x', '0x']);
		},
		repay: async (main, user, usdpAmount) => {
			const totalDebt = await context.vault.getTotalDebt(main.address, user);
			await context.usdp.approve(context.vault.address, totalDebt);
			return context.vaultManager.exit(
				main.address,
				0,
				usdpAmount,
				['0x', '0x', '0x', '0x'], // merkle proof mock
			);
		}
	}

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
	}
	return wrappers[mode];
}
