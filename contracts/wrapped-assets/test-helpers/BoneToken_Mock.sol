// SPDX-License-Identifier: MIT
// Origin Shiba contracts slightly changed for run in tests

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/wrapped-assets/IBoneToken.sol";


// BoneToken with Governance.
contract BoneToken_Mock is IBoneToken, ERC20("BONE SHIBASWAP", "BONE"), Ownable {
    using SafeMath for uint256;
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (TopDog).
    function mint(address _to, uint256 _amount) public override onlyOwner {
        _mint(_to, _amount);
    }

    function testMint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}