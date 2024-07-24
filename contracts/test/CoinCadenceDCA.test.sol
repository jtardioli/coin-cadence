// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {Test, console} from "forge-std/Test.sol";
import {CoinCadenceDCA} from "../src/CoinCadenceDCA.sol";
import {IERC20} from "../lib/IERC20.sol";

contract CoinCadenceDCATest is Test {
    address public user = makeAddr("user");

    address public swapRouterAddr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public wbtcAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC20 public wbtc = IERC20(wbtcAddress);
    IERC20 public usdc = IERC20(usdcAddress);

    CoinCadenceDCA coinCadenceDCA;

    function setUp() public {
        coinCadenceDCA = new CoinCadenceDCA(swapRouterAddr);
        deal(wbtcAddress, user, 1 ether);
    }

    /////////////////
    // constructor()
    /////////////////

    /////////////////
    // setJob()
    /////////////////

    function testOwnerCanCreateJob() public {}
    function testOwnerCanDeleteJob() public {}
    function testNotOwnerCantCreateJob() public {}
    function testNotOwnerCantDeleteJob() public {}
    function testErrorIfJobAlreadyExists() public {}

    /////////////////
    // getJob()
    /////////////////
    function testErrorIfJobDoesNotExist() public {}

    /////////////////
    // exactInput()
    /////////////////

    function testSwapExactInput() public {
        assertEq(usdc.balanceOf(user), 0);

        vm.prank(user);
        wbtc.approve(address(coinCadenceDCA), 5 ether);

        vm.prank(user);
        coinCadenceDCA.exactInput(
            ISwapRouter.ExactInputParams({
                path: hex"2260FAC5E5542a773Aa44fBCfeDf7C193bc2C5990001f4C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc20001f4A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                recipient: user,
                deadline: block.timestamp + 5 * 60,
                amountIn: 100000000,
                amountOutMinimum: 0
            })
        );

        assert(usdc.balanceOf(user) > 0);
    }

    /////////////////
    // processJob()
    /////////////////
    function testErrorIfJobDoesNotExistWhileJobRunning() public {}
    function testErrorIfInsufficientTimeInterval() public {}
    function testProccessJobSuccess() public {}

    /////////////////
    // getFirstAddress()
    /////////////////

    /////////////////
    // getSeconds()
    /////////////////
}
