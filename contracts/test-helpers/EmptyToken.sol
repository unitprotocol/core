// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./IAssetTestsMint.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EmptyToken is ERC20, IAssetTestsMint {
    using SafeMath for uint;

    event Burn(address indexed burner, uint value);

    /**
     * @dev Burns a specific amount of tokens from the caller.
     * @param _value The amount of token to be burned.
     * @return A boolean that indicates if the operation was successful.
     * @notice This function decreases the total supply of tokens.
     * @notice The caller must have a balance of at least `_value`.
     */
    function burn(uint _value) public returns (bool) {
        require(_value <= balanceOf(msg.sender), "BURN_INSUFFICIENT_BALANCE");

        _burn(msg.sender, _value);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens from the `_owner` on behalf of the caller.
     * @param _owner The address of the token owner.
     * @param _value The amount of token to be burned.
     * @return A boolean that indicates if the operation was successful.
     * @notice This function decreases the total supply of tokens.
     * @notice The caller must have allowance for `_owner`'s tokens of at least `_value`.
     */
    function burnFrom(address _owner, uint _value) public returns (bool) {
        require(_owner != address(0), "ZERO_ADDRESS");
        require(_value <= balanceOf(_owner), "BURNFROM_INSUFFICIENT_BALANCE");
        require(_value <= allowance(_owner, msg.sender), "BURNFROM_INSUFFICIENT_ALLOWANCE");

        _burn(_owner, _value);
        return true;
    }

    /**
     * @dev Constructor to create a new EmptyToken
     * @param _name Name of the new token.
     * @param _symbol Symbol of the new token.
     * @param _decimals Number of decimals of the new token.
     * @param _totalSupply Initial total supply of tokens.
     * @param _firstHolder Address that will receive the initial supply.
     * @notice The `_firstHolder` cannot be the zero address.
     * @notice The `_symbol` and `_name` are validated by `checkSymbolAndName`.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8         _decimals,
        uint          _totalSupply,
        address       _firstHolder
    ) ERC20(_name, _symbol)
    {
        require(_firstHolder != address(0), "ZERO_ADDRESS");
        checkSymbolAndName(_symbol,_name);

        _setupDecimals(_decimals);

        _mint(_firstHolder, _totalSupply);
    }

    /**
     * @dev Validates the symbol and name of the token.
     * @param _symbol The symbol of the token.
     * @param _name The name of the token.
     * @notice The symbol must be 3-8 characters in `[A-Za-z._]`.
     * @notice The name must be up to 128 characters and printable ASCII.
     */
    function checkSymbolAndName(
        string memory _symbol,
        string memory _name
    )
    internal
    pure
    {
        bytes memory s = bytes(_symbol);
        require(s.length >= 3 && s.length <= 8, "INVALID_SIZE");
        for (uint i = 0; i < s.length; i++) {
            // make sure symbol contains only [A-Za-z._]
            require(
                s[i] == 0x2E || (
            s[i] == 0x5F) || (
            s[i] >= 0x41 && s[i] <= 0x5A) || (
            s[i] >= 0x61 && s[i] <= 0x7A), "INVALID_VALUE");
        }
        bytes memory n = bytes(_name);
        require(n.length >= s.length && n.length <= 128, "INVALID_SIZE");
        for (uint i = 0; i < n.length; i++) {
            require(n[i] >= 0x20 && n[i] <= 0x7E, "INVALID_VALUE");
        }
    }

    /**
     * @dev Mints tokens to the specified address. Can only be called by the contract owner.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     * @notice This function increases the total supply of tokens.
     */
    function tests_mint(address to, uint amount) public override {
        _mint(to, amount);
    }
}