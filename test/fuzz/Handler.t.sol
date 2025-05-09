// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin tdsc;
    TDSCEngine tdscEngine;
    ERC20Mock wETH;
    ERC20Mock wBTC;
    uint256 public constant MAX_COLLATERAL = type(uint8).max;

    constructor(DecentralizedStableCoin _tdsc, TDSCEngine _tdscEngine) {
        tdscEngine = _tdscEngine;
        tdsc = _tdsc;

        address[] memory collaterlTokens = tdscEngine.getCollateralTokens();
        wETH = ERC20Mock(collaterlTokens[0]);
        wBTC = ERC20Mock(collaterlTokens[1]);
    }

    function depositeCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_COLLATERAL);
        vm.startPrank(msg.sender);
        collateral.mint(address(msg.sender), amountCollateral);
        ERC20Mock(collateral).approve(address(tdscEngine), amountCollateral);
        tdscEngine.depositeCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        uint256 userCollateralBalance = tdscEngine.getUserCollateralBalance(address(collateral));
        amountCollateral = bound(amountCollateral, 0, userCollateralBalance);
        if (amountCollateral == 0){
            return;
        }
        tdscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    //Helper functions
    function _getCollateralFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) return wETH;
        return wBTC;
    }
}
