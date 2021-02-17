module.exports = function(context, mode) {
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
				if (mode.startsWith('keydonix')) {
					return context.vaultManagerKeydonixMainAsset.spawn_Eth(
						usdpAmount,	// USDP
						{ value: mainAmount }
					);
				}
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
				if (mode.startsWith('keydonix')) {
					return context.vaultManagerKeydonixMainAsset.spawn_Eth(
						usdpAmount,	// USDP
						{ value: mainAmount }
					);
				}
			},
		},
		uniswapKeep3rMainAsset: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, from);
				return context.vaultManagerKeep3rUniswapMainAsset.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
					{ from },
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapMainAsset.spawn_Eth(
					usdpAmount,	// USDP
					{ value: mainAmount	}
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeep3rUniswapMainAsset.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				)
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapMainAsset.withdrawAndRepay(
					main.address,
					mainAmount, // main
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
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapMainAsset.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
				);
			},
			withdrawAndRepayEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapMainAsset.withdrawAndRepay_Eth(
					mainAmount,
					usdpAmount,
				);
			},
		},
		uniswapKeep3rPoolToken: {
			spawn: async (main, mainAmount, usdpAmount, { from = context.deployer, noApprove } = {}) => {
				if (!noApprove)
					await context.approveCollaterals(main, mainAmount, from);
				return context.vaultManagerKeep3rUniswapPoolToken.spawn(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			join: async (main, mainAmount, usdpAmount) => {
				await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerKeep3rUniswapPoolToken.depositAndBorrow(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapPoolToken.withdrawAndRepay(
					main.address,
					mainAmount, // main
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
			withdrawAndRepay: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapPoolToken.withdrawAndRepay(
					main.address,
					mainAmount,
					usdpAmount,
				);
			},
			spawnEth: async (mainAmount, usdpAmount) => {
				return context.vaultManagerKeep3rUniswapMainAsset.spawn_Eth(
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
		bearingAssetSimple: {
			join: async (main, mainAmount, usdpAmount, { noApprove } = {}) => {
				if (!noApprove)
					await main.approve(context.vault.address, mainAmount);
				return context.vaultManagerSimple.join(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			exit: async (main, mainAmount, usdpAmount) => {
				return context.vaultManagerSimple.exit(
					main.address,
					mainAmount, // main
					usdpAmount,	// USDP
				);
			},
			triggerLiquidation: (main, user, from = context.deployer) => {
				return context.liquidatorSimple.triggerLiquidation(
					main.address,
					user,
					{ from }
				);
			}
		},
	}
	return wrappers[mode];
}
