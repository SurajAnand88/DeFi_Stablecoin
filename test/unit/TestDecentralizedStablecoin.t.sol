// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {DeployDecentralizedStablecoin} from "script/DeployDecentralizedStablecoin.s.sol";
import {console} from "forge-std/Console.sol";

contract TestDecentralizedStablecoin is Test {
    DecentralizedStableCoin public decentralizedStablecoin;
    DeployDecentralizedStablecoin public deployer;
    address public USER = makeAddr("USER");
    uint256 public constant MINT_BALANCE = 100000;
    uint256 public constant BURN_BALANCE = 5000;

    function setUp() public {
        deployer = new DeployDecentralizedStablecoin();
        decentralizedStablecoin = deployer.run();
    }

    function testMintOnDecentralizedStablecoin() public {
        vm.prank(DEFAULT_SENDER);
        decentralizedStablecoin.mint(USER,MINT_BALANCE);
        assertEq(decentralizedStablecoin.balanceOf(USER), MINT_BALANCE);
    }

    function testBurnOnDecentralizedStablecoin() public {
        vm.prank(DEFAULT_SENDER);
        decentralizedStablecoin.mint(DEFAULT_SENDER, MINT_BALANCE);
        vm.prank(DEFAULT_SENDER);
        decentralizedStablecoin.burn(BURN_BALANCE);
        assertEq(decentralizedStablecoin.balanceOf(DEFAULT_SENDER), MINT_BALANCE-BURN_BALANCE);
    }



}
