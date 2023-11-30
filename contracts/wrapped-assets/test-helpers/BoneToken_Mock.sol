// SPDX-License-Identifier: MIT
// Origin Shiba contracts slightly changed for run in tests

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/wrapped-assets/IBoneToken.sol";

/**
 * @title BoneToken_Mock
 * @dev Implementation of the IBoneToken interface with ERC20 token standard and Ownable features.
 * This token is used for testing purposes and includes governance capabilities.
 */
contract BoneToken_Mock is IBoneToken, ERC20("BONE SHIBASWAP", "BONE"), Ownable {
    using SafeMath for uint256;
    /**
     * @dev Mints `_amount` tokens to address `_to`.
     * Must only be called by the contract owner (TopDog).
     * @param _to The address of the beneficiary that will receive the tokens.
     * @param _amount The number of tokens to mint.
     */
    function mint(address _to, uint256 _amount) public override onlyOwner {
        _mint(_to, _amount);
    }

    /**
     * @dev Mints `_amount` tokens to address `_to` without access restriction.
     * This function is meant for testing purposes.
     * @param _to The address of the beneficiary that will receive the tokens.
     * @param _amount The number of tokens to mint.
     */
    function testMint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}