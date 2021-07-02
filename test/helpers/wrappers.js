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
		}
	}

	const wrappers = {
		keydonixMainAsset: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, from);
				return context.vaultManagerKeydonixMainAsset.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					{ from },
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.spawn_Eth(
					usdpAmount,	// USDP
					{ value: mainAmount }
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeydonixMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
				)
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeydonixMainAsset.triggerLiquidation(
					main.address,
					user,
					['0x', '0x', '0x', '0x'], // main price proof
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
				);
			},
			withdrawAndRepayEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					usdpAmount,
				);
			},
		},
		keydonixPoolToken: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, from);
				return context.vaultManagerKeydonixPoolToken.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // underlying token price proof
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeydonixPoolToken.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // underlying token price proof
				);
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixPoolToken.withdrawAndRepay(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeydonixPoolToken.triggerLiquidation(
					main.address,
					user,
					['0x', '0x', '0x', '0x'], // main price proof
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixPoolToken.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.spawn_Eth(
					usdpAmount,	// USDP
					{ value: mainAmount }
				);
			},
		},
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
	}
	return wrappers[mode];
}
