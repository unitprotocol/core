// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Parameters.sol";
import "./helpers/SafeMath.sol";

contract USDP is Auth {
    using SafeMath for uint;

    string  public constant name     = "USD ThePay.cash Stablecoin";
    string  public constant symbol   = "USDP";
    string  public constant version  = "1";
    uint8   public constant decimals = 18;
    uint    public totalSupply;

    mapping(address => uint)                      public balanceOf;
    mapping(address => mapping(address => uint))  public allowance;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor(address _parameters) public Auth(_parameters) {}

    function transfer(address to, uint amount) external returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint amount) public returns (bool) {
        require(to != address(0), "USDP: ZERO_ADDRESS");
        require(balanceOf[from] >= amount, "USDP: INSUFFICIENT_BALANCE");

        if (from != msg.sender) {
            _approve(from, msg.sender, allowance[from][msg.sender].sub(amount));
        }
        balanceOf[from] = balanceOf[from].sub(amount);
        balanceOf[to] = balanceOf[to].add(amount);

        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint amount) external onlyVault {
        require(to != address(0), "USDP: ZERO_ADDRESS");

        balanceOf[to] = balanceOf[to].add(amount);
        totalSupply = totalSupply.add(amount);

        emit Transfer(address(0), to, amount);
    }

    function burn(uint amount) external onlyManager {
        _burn(msg.sender, amount);
    }

    function burn(address from, uint amount) external onlyVault {
        _burn(from, amount);
    }

    function approve(address spender, uint amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowance[msg.sender][spender].add(addedValue));
        return true;
    }

    function _approve(address owner, address spender, uint amount) internal virtual {
        require(owner != address(0), "USDP: approve from the zero address");
        require(spender != address(0), "USDP: approve to the zero address");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burn(address from, uint amount) internal virtual {
        balanceOf[from] = balanceOf[from].sub(amount);
        totalSupply = totalSupply.sub(amount);

        emit Transfer(from, address(0), amount);
    }
}
