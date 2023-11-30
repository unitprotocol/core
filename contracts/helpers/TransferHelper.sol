// SPDX-License-Identifier: GPL-3.0-or-later

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

/**
 * @title TransferHelper
 * @dev Library to provide safe methods for interacting with ERC20 tokens and sending ETH.
 */
library TransferHelper {
    
    /**
     * @dev Approves the `token` to spend `value` amount on behalf of the caller.
     * @param token The address of the ERC20 token contract.
     * @param to The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    /**
     * @dev Transfers `value` amount of `token` to the address `to`.
     * @param token The address of the ERC20 token contract.
     * @param to The recipient address.
     * @param value The amount of tokens to be transferred.
     */
    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    /**
     * @dev Transfers `value` amount of `token` from the `from` address to the `to` address.
     * @param token The address of the ERC20 token contract.
     * @param from The address which you want to send tokens from.
     * @param to The recipient address.
     * @param value The amount of tokens to be transferred.
     */
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    /**
     * @dev Transfers `value` amount of Ether to the address `to`.
     * @param to The recipient address.
     * @param value The amount of Ether to be transferred.
     */
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}