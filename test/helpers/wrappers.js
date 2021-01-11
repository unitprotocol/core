const MAX_UINT = new web3.utils.BN('0x' + 'ff'.repeat(32));

module.exports = function(context, mode) {
	const wrappers = {
		keydonixMainAsset: {
			spawn: async (main, mainAmount, colAmount, usdpAmount, { from = context.deployer, noApprove, noColApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, noColApprove ? '0' : colAmount, from);
				return context.vaultManagerKeydonixMainAsset.spawn(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
					{ from },
				);
			},
			spawnEth: async (mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, colAmount);
				if (mode.startsWith('keydonix')) {
					return context.vaultManagerKeydonixMainAsset.spawn_Eth(
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // COL price proof
						{ value: mainAmount }
					);
				}
			},
			join: async (main, mainAmount, colAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeydonixMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				)
			},
			exit: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeydonixMainAsset.triggerLiquidation(
					main.address,
					user,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			withdrawAndRepayEth: async (mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			withdrawAndRepayCol: async (main, mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeydonixMainAsset.withdrawAndRepayUsingCol(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			repayUsingCol: async (main, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeydonixMainAsset.repayUsingCol(
					main.address,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
		},
		keydonixPoolToken: {
			spawn: async (main, mainAmount, colAmount, usdpAmount, { from = context.deployer, noApprove, noColApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, noColApprove ? '0' : colAmount, from);
				return context.vaultManagerKeydonixPoolToken.spawn(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // underlying token price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			join: async (main, mainAmount, colAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeydonixPoolToken.depositAndBorrow(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // underlying token price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			exit: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeydonixPoolToken.withdrawAndRepay(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeydonixPoolToken.triggerLiquidation(
					main.address,
					user,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeydonixPoolToken.withdrawAndRepay(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			withdrawAndRepayCol: async (main, mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeydonixPoolToken.withdrawAndRepayUsingCol(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // main price proof
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			repayUsingCol: async (main, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeydonixPoolToken.repayUsingCol(
					main.address,
					usdpAmount,
					['0x', '0x', '0x', '0x'], // COL price proof
				);
			},
			spawnEth: async (mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, colAmount);
				if (mode.startsWith('keydonix')) {
					return context.vaultManagerKeydonixMainAsset.spawn_Eth(
						colAmount, // COL
						usdpAmount,	// USDP
						['0x', '0x', '0x', '0x'], // COL price proof
						{ value: mainAmount }
					);
				}
			},
		},
		keep3rMainAsset: {
			spawn: async (main, mainAmount, colAmount, usdpAmount, { from = context.deployer, noApprove, noColApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, noColApprove ? '0' : colAmount, from);
				return context.vaultManagerKeep3rMainAsset.spawn(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
					{ from },
				);
			},
			spawnEth: async (mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeep3rMainAsset.spawn_Eth(
					colAmount, // main
					usdpAmount,	// USDP
					{ value: mainAmount	}
				);
			},
			join: async (main, mainAmount, colAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeep3rMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
				)
			},
			exit: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeep3rMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeep3rMainAsset.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeep3rMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayEth: async (mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeep3rMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					colAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayCol: async (main, mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeep3rMainAsset.withdrawAndRepayUsingCol(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
				);
			},
			repayUsingCol: async (main, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeep3rMainAsset.repayUsingCol(
					main.address,
					usdpAmount,
				);
			},
		},
		keep3rPoolToken: {
			spawn: async (main, mainAmount, colAmount, usdpAmount, { from = context.deployer, noApprove, noColApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, noColApprove ? '0' : colAmount, from);
				return context.vaultManagerKeep3rPoolToken.spawn(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
				);
			},
			join: async (main, mainAmount, colAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeep3rPoolToken.depositAndBorrow(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
				);
			},
			exit: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeep3rPoolToken.withdrawAndRepay(
					main.address,
					mainAmount, // main
					colAmount, // COL
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeep3rPoolToken.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, colAmount, usdpAmount) => {
				return context.vaultManagerKeep3rPoolToken.withdrawAndRepay(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayCol: async (main, mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeep3rPoolToken.withdrawAndRepayUsingCol(
					main.address,
					mainAmount,
					colAmount,
					usdpAmount,
				);
			},
			repayUsingCol: async (main, usdpAmount) => {
				await context.col.approve(context.vault.address, MAX_UINT);
				return context.vaultManagerKeep3rPoolToken.repayUsingCol(
					main.address,
					usdpAmount,
				);
			},
			spawnEth: async (mainAmount, colAmount, usdpAmount) => {
				await context.col.approve(context.vault.address, colAmount);
				return context.vaultManagerKeep3rMainAsset.spawn_Eth(
					colAmount, // main
					usdpAmount,	// USDP
					{ value: mainAmount	}
				);
			},
		},
		chainlinkMainAsset: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await main.approve(context.vault.address, mainAmount, { from });
				return context.vaultManagerChainlinkMainAsset.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					{ from },
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerChainlinkMainAsset.spawn_Eth(
					usdpAmount,	// USDP
					{ value: mainAmount	}
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerChainlinkMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				)
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerChainlinkMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorChainlinkMainAsset.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerChainlinkMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerChainlinkMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					usdpAmount,
				);
			},
		},
		sushiswapKeep3rMainAsset: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await main.approve(context.vault.address, mainAmount, { from });
				return context.vaultManagerKeep3rSushiSwapMainAsset.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					{ from },
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapMainAsset.spawn_Eth(
					usdpAmount,	// USDP
					{ value: mainAmount	}
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeep3rSushiSwapMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				)
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeep3rSushiSwapMainAsset.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					usdpAmount,
				);
			},
		},
		sushiswapKeep3rPoolToken: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await main.approve(context.vault.address, mainAmount, { from });
				return context.vaultManagerKeep3rSushiSwapPoolToken.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeep3rSushiSwapPoolToken.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapPoolToken.withdrawAndRepay(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorKeep3rSushiSwapPoolToken.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			},
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rSushiSwapPoolToken.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
				);
			},
		},
	}
	return wrappers[mode];
}
