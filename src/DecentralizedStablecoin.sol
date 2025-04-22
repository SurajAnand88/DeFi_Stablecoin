// SPDX-License-Identifier: MIT

//Layout of the contract
// version
// imports
// errors
// interfaces, libraried , contracts
// Events
// Modifiers
// Functions

// Layout of the Functions
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view and pure functions

/**
 * @title Dencentralized Stable Coin
 * @author Suraj
 * Collateral : Exogenous
 * Minting : Algorithmic
 * Relative Stability : Pegged to USD
 *
 *
 *
 * This is the contract is meant to be governed by DSCEngine. This contract is the ERC20 implimentation of our stablecoin system.
 *
 */
pragma solidity 0.8.18;

import {ERC20, ERC20Burnable} from "../lib/openzepplin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzepplin-contracts/contracts/access/Ownable.sol";

error TDSC_AmountMustBeGreaterThanZero();
error TDSC_BurnAmountExceedsBalance();
error TDSC_NotZeroAddress();

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    constructor() ERC20("DecentralizedStablecoin", "TDSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) revert TDSC_AmountMustBeGreaterThanZero();
        if (balance < _amount) revert TDSC_BurnAmountExceedsBalance();

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) revert TDSC_NotZeroAddress();
        if (_amount <= 0) revert TDSC_AmountMustBeGreaterThanZero();

        _mint(_to, _amount);
        return true;
    }
}
