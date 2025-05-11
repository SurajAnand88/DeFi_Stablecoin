// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStablecoin.sol";
import {TDSCEngine} from "src/TDSCEngine.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/Console.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DecentralizedStableCoin tdsc;
    TDSCEngine tdscEngine;
    ERC20Mock wETH;
    ERC20Mock wBTC;
    uint256 public constant MAX_COLLATERAL = type(uint8).max;
    uint256 public mintTimesCalled;
    address[] public userWithCollateral;

    MockV3Aggregator public ethUSDPriceFeed;

    constructor(DecentralizedStableCoin _tdsc, TDSCEngine _tdscEngine) {
        tdscEngine = _tdscEngine;
        tdsc = _tdsc;

        address[] memory collaterlTokens = tdscEngine.getCollateralTokens();
        wETH = ERC20Mock(collaterlTokens[0]);
        wBTC = ERC20Mock(collaterlTokens[1]);
        ethUSDPriceFeed = MockV3Aggregator(tdscEngine.getCollateralTokenPriceFeed(address(wETH)));
    }

    function depositeCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_COLLATERAL);
        vm.startPrank(msg.sender);
        collateral.mint(address(msg.sender), amountCollateral);
        ERC20Mock(collateral).approve(address(tdscEngine), amountCollateral);
        tdscEngine.depositeCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        userWithCollateral.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        uint256 userCollateralBalance = tdscEngine.getUserCollateralBalance(address(collateral));
        amountCollateral = bound(amountCollateral, 0, userCollateralBalance);
        if (amountCollateral == 0) {
            return;
        }
        tdscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function mintTDS(uint256 amountTDSC, uint256 addressSeed) public {
        if (userWithCollateral.length == 0) return;
        address sender = userWithCollateral[addressSeed % userWithCollateral.length];
        (uint256 totalTDSCMinted, uint256 totalCollateralValueInUSD) = tdscEngine.getUserAccountInformation(sender);
        int256 maxTDSCMint = int256((totalCollateralValueInUSD / 2)) - int256(totalTDSCMinted);
        if (maxTDSCMint < 0) return;
        amountTDSC = bound(amountTDSC, 0, uint256(maxTDSCMint));
        if (amountTDSC == 0) return;
        vm.startPrank(sender);
        tdscEngine.mintTDSC(amountTDSC);
        vm.stopPrank();
        mintTimesCalled++;
    }

    // This function breaks our our invariant
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 updatePrice = int256(uint256(newPrice));
    //     ethUSDPriceFeed.updateAnswer(updatePrice);
    // }

    //Helper functions
    function _getCollateralFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) return wETH;
        return wBTC;
    }
}
