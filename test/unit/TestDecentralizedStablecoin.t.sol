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
    string public constant EXPECTED_NAME = "DecentralizedStablecoin";
    string public constant EXPECTED_SYMBOL = "TDSC";

    function setUp() external {
        deployer = new DeployDecentralizedStablecoin();
        decentralizedStablecoin = deployer.run();
    }

    function testNameAndSymbolShouldBeCorrect() public view {
        assertEq(decentralizedStablecoin.name(), EXPECTED_NAME);
        assertEq(decentralizedStablecoin.symbol(), EXPECTED_SYMBOL);
    }

    function testMintOnDecentralizedStablecoin() public defaultSender {
        decentralizedStablecoin.mint(USER, MINT_BALANCE);
        assertEq(decentralizedStablecoin.balanceOf(USER), MINT_BALANCE);
    }

    function testBurnOnDecentralizedStablecoin() public defaultSender {
        decentralizedStablecoin.mint(DEFAULT_SENDER, MINT_BALANCE);
        vm.prank(DEFAULT_SENDER);
        decentralizedStablecoin.burn(BURN_BALANCE);
        assertEq(decentralizedStablecoin.balanceOf(DEFAULT_SENDER), MINT_BALANCE - BURN_BALANCE);
    }

    function testMintingShouldRevertWithAmountGreaterThanZero() public defaultSender {
        vm.expectRevert(DecentralizedStableCoin.TDSC__AmountMustBeGreaterThanZero.selector);
        decentralizedStablecoin.mint(DEFAULT_SENDER, 0);
    }

    function testMintShouldRevertWithZeroAddress() public defaultSender {
        vm.expectRevert(DecentralizedStableCoin.TDSC__NotZeroAddress.selector);
        decentralizedStablecoin.mint(address(0), MINT_BALANCE);
    }

    function testBurnShouldRevertWithAmountGreaterThanZero() public defaultSender {
        vm.expectRevert(DecentralizedStableCoin.TDSC__AmountMustBeGreaterThanZero.selector);
        decentralizedStablecoin.burn(0);
    }

    function testBurnShouldRevertWithAmountExceedsBalance() public defaultSender {
        decentralizedStablecoin.mint(DEFAULT_SENDER, BURN_BALANCE);
        vm.prank(DEFAULT_SENDER);
        vm.expectRevert(DecentralizedStableCoin.TDSC__BurnAmountExceedsBalance.selector);
        decentralizedStablecoin.burn(MINT_BALANCE);
    }

    modifier defaultSender() {
        vm.prank(DEFAULT_SENDER);
        _;
    }
}
