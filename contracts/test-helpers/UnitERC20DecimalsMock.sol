// SPDX-License-Identifier: MIT
// contract from openzeppelin:3.4.0 for testing ported UnitERC20
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/mocks/ERC20DecimalsMock.sol
// see original license here https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/LICENSE

pragma solidity >=0.6.0 <0.8.0;

import "../helpers/UnitERC20.sol";

contract UnitERC20DecimalsMock is UnitERC20 {
    constructor (string memory name, string memory symbol, uint8 decimals) UnitERC20(decimals) {
        _initNameAndSymbol(name, symbol);
    }
}