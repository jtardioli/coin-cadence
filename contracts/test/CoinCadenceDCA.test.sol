// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";
import {Test, console} from "forge-std/Test.sol";
import {CoinCadenceDCA} from "../src/CoinCadenceDCA.sol";
import {IERC20} from "../lib/IERC20.sol";

contract CoinCadenceDCATest is Test {
    address public user = makeAddr("user");

    address public swapRouterAddr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public wethAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    IERC20 public weth = IERC20(wethAddress);

    CoinCadenceDCA coinCadenceDCA;

    function setUp() public {
        coinCadenceDCA = new CoinCadenceDCA(swapRouterAddr);
        deal(wethAddress, user, 1 ether);
    }

    // deal user the token x
    // user approves my DCA contract to spend the token x
    // transfer the token to my contract x
    // approve swap router to spend the token
    // call exactInput
    function test() public {
        vm.prank(user);
        weth.approve(address(coinCadenceDCA), 5 ether);

        console.log("My Logs");
        console.log(weth.balanceOf(user));
        console.log(weth.allowance(user, address(coinCadenceDCA)));

        vm.prank(user);
        address amount = coinCadenceDCA.exactInput(
            ISwapRouter.ExactInputParams({
                path: hex"2260FAC5E5542a773Aa44fBCfeDf7C193bc2C59900000aC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200000aA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                recipient: user,
                deadline: 0,
                amountIn: 0.5 ether,
                amountOutMinimum: 0
            })
        );

        console.log(weth.balanceOf(user));
        console.log(weth.allowance(address(coinCadenceDCA), swapRouterAddr));

        console.log(amount);
    }
}
