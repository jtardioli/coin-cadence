// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";
import {Test, console} from "forge-std/Test.sol";
import {CoinCadenceDCA} from "../src/CoinCadenceDCA.sol";

contract CoinCadenceDCATest is Test {
    address public user = makeAddr("user");

    address public swapRouterAddr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    CoinCadenceDCA coinCadenceDCA;

    function setUp() public {
        coinCadenceDCA = new CoinCadenceDCA(swapRouterAddr);
    }

    function testDeployment() public {
        address amount = coinCadenceDCA.exactInput(
            ISwapRouter.ExactInputParams({
                path: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C59900000aC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200000aA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                recipient: user,
                deadline: 0,
                amountIn: 5,
                amountOutMinimum: 0
            })
        );

        console.log("amount", amount);
    }
}
