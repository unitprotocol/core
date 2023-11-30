// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity 0.7.6;

import "./IAssetTestsMint.sol";
import "../interfaces/IWETH.sol";
import "../helpers/SafeMath.sol";

/* @title Mock contract for Wrapped Ether (WETH) */
contract WETHMock is IWETH, IAssetTestsMint {
    using SafeMath for uint;

    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    uint testsMinted = 0;

    /* @dev Allows contract to receive Ether */
    receive() external payable {
        deposit();
    }

    /* 
     * @dev Deposits Ether to wrap into WETH
     */
    function deposit() public override payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /* 
     * @dev Withdraws Ether by unwrapping WETH
     * @param wad The amount of WETH to unwrap
     */
    function withdraw(uint wad) public override {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        msg.sender.transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /* 
     * @dev Returns the total supply of WETH, including any test minted amount
     * @return The total supply of WETH
     */
    function totalSupply() public view returns (uint) {
        return address(this).balance + testsMinted;
    }

    /* 
     * @dev Approves another address to spend WETH on the caller's behalf
     * @param guy The address to approve
     * @param wad The amount of WETH to approve
     * @return A boolean value indicating whether the operation succeeded
     */
    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        Approval(msg.sender, guy, wad);
        return true;
    }

    /* 
     * @dev Transfers WETH to another address
     * @param dst The destination address
     * @param wad The amount of WETH to transfer
     * @return A boolean value indicating whether the operation succeeded
     */
    function transfer(address dst, uint wad) public override returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    /* 
     * @dev Transfers WETH from one address to another
     * @param src The source address
     * @param dst The destination address
     * @param wad The amount of WETH to transfer
     * @return A boolean value indicating whether the operation succeeded
     */
    function transferFrom(address src, address dst, uint wad)
        public override
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        Transfer(src, dst, wad);

        return true;
    }

    /* 
     * @dev Mints WETH for testing purposes
     * @param to The address to mint WETH to
     * @param amount The amount of WETH to mint
     */
    function tests_mint(address to, uint amount) public override {
        require(to != address(0), "Unit Protocol: ZERO_ADDRESS");

        balanceOf[to] = balanceOf[to].add(amount);
        testsMinted = testsMinted.add(amount);
    }
}