// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title IUniswapV2PairFull
 * @dev Interface for a Uniswap V2 Pair with full functionality.
 */
interface IUniswapV2PairFull {
    // Events
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev Returns the name of the pair.
     * @return The name of the pair.
     */
    function name() external pure returns (string memory);

    /**
     * @dev Returns the symbol of the pair.
     * @return The symbol of the pair.
     */
    function symbol() external pure returns (string memory);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * @return The number of decimals for the pair.
     */
    function decimals() external pure returns (uint8);

    /**
     * @dev Returns the total supply of the liquidity tokens.
     * @return The total supply.
     */
    function totalSupply() external view returns (uint);

    /**
     * @dev Returns the amount of tokens owned by `owner`.
     * @param owner The address of the token owner.
     * @return The balance of the owner.
     */
    function balanceOf(address owner) external view returns (uint);

    /**
     * @dev Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner`.
     * @param owner The address of the token owner.
     * @param spender The address which is allowed to spend the tokens.
     * @return The amount of tokens allowed to be spent.
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * @dev Approves `spender` to spend `value` tokens on behalf of the caller.
     * @param spender The address which is allowed to spend the tokens.
     * @param value The number of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function approve(address spender, uint value) external returns (bool);

    /**
     * @dev Transfers `value` tokens to address `to`.
     * @param to The address of the recipient.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address to, uint value) external returns (bool);

    /**
     * @dev Transfers `value` tokens from address `from` to address `to`.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address from, address to, uint value) external returns (bool);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by EIP-712.
     * @return The domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @dev Returns the hash of the permit type used by the `permit` function.
     * @return The permit typehash.
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev Returns the current nonce for `owner`. This value must be included whenever a signature is generated for `permit`.
     * @param owner The address whose nonce is being fetched.
     * @return The nonce of the owner.
     */
    function nonces(address owner) external view returns (uint);

    /**
     * @dev Allows for the approval of `spender` to spend `value` tokens on behalf of `owner` via off-chain signatures.
     * @param owner The address of the token owner.
     * @param spender The address which is allowed to spend the tokens.
     * @param value The number of tokens to be spent.
     * @param deadline The time at which the permit is no longer valid.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Returns the minimum liquidity threshold for adding liquidity to the pool.
     * @return The minimum liquidity threshold.
     */
    function MINIMUM_LIQUIDITY() external pure returns (uint);

    /**
     * @dev Returns the factory address.
     * @return The factory address.
     */
    function factory() external view returns (address);

    /**
     * @dev Returns the address of the first token in the pair.
     * @return The address of the first token.
     */
    function token0() external view returns (address);

    /**
     * @dev Returns the address of the second token in the pair.
     * @return The address of the second token.
     */
    function token1() external view returns (address);

    /**
     * @dev Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * @return reserve0 The reserve of token0.
     * @return reserve1 The reserve of token1.
     * @return blockTimestampLast The last block timestamp when the reserves were updated.
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /**
     * @dev Returns the last cumulative price of token0.
     * @return The last cumulative price of token0.
     */
    function price0CumulativeLast() external view returns (uint);

    /**
     * @dev Returns the last cumulative price of token1.
     * @return The last cumulative price of token1.
     */
    function price1CumulativeLast() external view returns (uint);

    /**
     * @dev Returns the value of the current liquidity threshold.
     * @return The value of kLast.
     */
    function kLast() external view returns (uint);

    /**
     * @dev Adds liquidity to the pool and mints new LP tokens to `to`.
     * @param to The address receiving the new liquidity tokens.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function mint(address to) external returns (uint liquidity);

    /**
     * @dev Removes liquidity from the pool and burns LP tokens to withdraw the underlying assets.
     * @param to The address receiving the underlying assets.
     * @return amount0 The amount of the first token.
     * @return amount1 The amount of the second token.
     */
    function burn(address to) external returns (uint amount0, uint amount1);

    /**
     * @dev Executes a swap of `amount0Out` of token0 for `amount1Out` of token1, or vice versa.
     * @param amount0Out The amount of token0 to be sent to `to`.
     * @param amount1Out The amount of token1 to be sent to `to`.
     * @param to The recipient address.
     * @param data Additional data passed to the swap function, for use in callback.
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    /**
     * @dev Forces balances to match the reserves.
     * @param to The address that receives the tokens.
     */
    function skim(address to) external;

    /**
     * @dev Updates the reserves to match the current balances.
     */
    function sync() external;

    /**
     * @dev Initializes the pair with the provided token addresses. This is called by the factory contract.
     * @param token0 The address of the first token.
     * @param token1 The address of the second token.
     */
    function initialize(address token0, address token1) external;
}