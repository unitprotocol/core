// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./VaultParameters.sol";
import "./helpers/SafeMath.sol";


/**
 * @title USDP token implementation
 * @dev ERC20 token
 **/
contract USDP is Auth {
    using SafeMath for uint;

    // name of the token
    string public constant name = "USDP Stablecoin";

    // symbol of the token
    string public constant symbol = "USDP";

    // version of the token
    string public constant version = "1";

    // number of decimals the token uses
    uint8 public constant decimals = 18;

    // total token supply
    uint public totalSupply;

    // balance information map
    mapping(address => uint) public balanceOf;

    // token allowance mapping
    mapping(address => mapping(address => uint)) public allowance;

    // minters mapping
    mapping(address => bool) public isMinter;

    /**
     * @dev Trigger on any successful call to approve(address spender, uint amount)
    **/
    event Approval(address indexed owner, address indexed spender, uint value);

    /**
     * @dev Trigger when tokens are transferred, including zero value transfers
    **/
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev Trigger minter is set/unset
    **/
    event Minter(address indexed who, bool flag);

    modifier onlyMinter() {
        require(isMinter[msg.sender], "Unit Protocol: NOT_A_MINTER");
        _;
    }

    /**
      * @param _parameters The address of system parameters contract
     **/
    constructor(address _parameters) Auth(_parameters) {}

    /**
      * @notice Only manager is able to manage minters
      * @dev Allows and disallows 'who' to mint/burn the token
      * @param who The address of the minter
      * @param flag The permission flag
     **/
    function setMinter(address who, bool flag) external onlyManager {
        isMinter[who] = flag;
        emit Minter(who, flag);
    }

    /**
      * @notice Only minter can mint USDP
      * @dev Mints 'amount' of tokens to address 'to', and MUST fire the
      * Transfer event
      * @param to The address of the recipient
      * @param amount The amount of token to be minted
     **/
    function mint(address to, uint amount) external onlyMinter {
        require(to != address(0), "Unit Protocol: ZERO_ADDRESS");

        balanceOf[to] = balanceOf[to].add(amount);
        totalSupply = totalSupply.add(amount);

        emit Transfer(address(0), to, amount);
    }

    /**
      * @notice Only manager can burn tokens from manager's balance
      * @dev Burns 'amount' of tokens, and MUST fire the Transfer event
      * @param amount The amount of token to be burned
     **/
    function burn(uint amount) external onlyManager {
        _burn(msg.sender, amount);
    }

    /**
      * @notice Only minter can burn tokens from any address
      * @dev Burns 'amount' of tokens from 'from' address, and MUST fire the Transfer event
      * @param from The address of the balance owner
      * @param amount The amount of token to be burned
     **/
    function burn(address from, uint amount) external onlyMinter {
        _burn(from, amount);
    }

    /**
      * @dev Transfers 'amount' of tokens to address 'to', and MUST fire the Transfer event. The
      * function SHOULD throw if the _from account balance does not have enough tokens to spend.
      * @param to The address of the recipient
      * @param amount The amount of token to be transferred
     **/
    function transfer(address to, uint amount) external returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    /**
      * @dev Transfers 'amount' of tokens from address 'from' to address 'to', and MUST fire the
      * Transfer event
      * @param from The address of the sender
      * @param to The address of the recipient
      * @param amount The amount of token to be transferred
     **/
    function transferFrom(address from, address to, uint amount) public returns (bool) {
        require(to != address(0), "Unit Protocol: ZERO_ADDRESS");
        require(balanceOf[from] >= amount, "Unit Protocol: INSUFFICIENT_BALANCE");

        if (from != msg.sender) {
            require(allowance[from][msg.sender] >= amount, "Unit Protocol: INSUFFICIENT_ALLOWANCE");
            _approve(from, msg.sender, allowance[from][msg.sender].sub(amount));
        }
        balanceOf[from] = balanceOf[from].sub(amount);
        balanceOf[to] = balanceOf[to].add(amount);

        emit Transfer(from, to, amount);
        return true;
    }

    /**
      * @dev Allows 'spender' to withdraw from your account multiple times, up to the 'amount' amount. If
      * this function is called again it overwrites the current allowance with 'amount'.
      * @param spender The address of the account able to transfer the tokens
      * @param amount The amount of tokens to be approved for transfer
     **/
    function approve(address spender, uint amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function _approve(address owner, address spender, uint amount) internal virtual {
        require(owner != address(0), "Unit Protocol: approve from the zero address");
        require(spender != address(0), "Unit Protocol: approve to the zero address");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burn(address from, uint amount) internal virtual {
        balanceOf[from] = balanceOf[from].sub(amount);
        totalSupply = totalSupply.sub(amount);

        emit Transfer(from, address(0), amount);
    }
}
