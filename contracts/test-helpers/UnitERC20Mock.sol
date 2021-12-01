// SPDX-License-Identifier: MIT
// contract from openzeppelin:3.4.0 for testing ported UnitERC20
// https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/release-v3.4/contracts/mocks/ERC20Mock.sol
// see original license here https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/LICENSE

pragma solidity >=0.6.0 <0.8.0;

import "../helpers/UnitERC20.sol";

// mock class using ERC20
contract UnitERC20Mock is UnitERC20 {
    constructor (
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) payable UnitERC20(18) {
        _initNameAndSymbol(name, symbol);
        _mint(initialAccount, initialBalance);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}