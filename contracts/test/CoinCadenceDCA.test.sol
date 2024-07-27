// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {Test, console} from "forge-std/Test.sol";
import {CoinCadenceDCA} from "../src/CoinCadenceDCA.sol";
import {IERC20} from "../lib/IERC20.sol";

contract CoinCadenceDCATest is Test {
    uint256 public constant SECONDS_IN_A_WEEK = 60 * 60 * 24 * 7;
    uint256 public constant SECONDS_IN_30_MINUTES = 60 * 30;

    address public user = makeAddr("user");

    address public swapRouterAddr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public wbtcAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes public wbtcToUsdcPath =
        hex"2260FAC5E5542a773Aa44fBCfeDf7C193bc2C5990001f4C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc20001f4A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    IERC20 public wbtc = IERC20(wbtcAddress);
    IERC20 public usdc = IERC20(usdcAddress);

    CoinCadenceDCA coinCadenceDCA;

    function setUp() public {
        coinCadenceDCA = new CoinCadenceDCA(swapRouterAddr);
        deal(wbtcAddress, user, 1 ether);
    }

    /////////////////
    // createJob()
    /////////////////

    function testUserCanCreateJob() public {
        vm.startPrank(user);
        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            SECONDS_IN_30_MINUTES,
            100000000,
            SECONDS_IN_A_WEEK,
            block.timestamp - SECONDS_IN_A_WEEK
        );
        vm.stopPrank();

        CoinCadenceDCA.DCAJobProperties memory storedJob = coinCadenceDCA.getJob(jobKey);

        assertEq(storedJob.path, wbtcToUsdcPath);
        assertEq(storedJob.owner, user);
        assertEq(storedJob.recipient, user);
        assertEq(storedJob.secondsToWaitForTx, SECONDS_IN_30_MINUTES);
        assertEq(storedJob.amountIn, 100000000);
        assertEq(storedJob.frequencyInSeconds, SECONDS_IN_A_WEEK);
        assertEq(storedJob.prevRunTimestamp, block.timestamp - SECONDS_IN_A_WEEK);
        assert(storedJob.initialized);
    }

    /////////////////
    // deleteJob()
    /////////////////

    function testUserCanDeleteJob() public {
        vm.startPrank(user);
        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            SECONDS_IN_30_MINUTES,
            100000000,
            SECONDS_IN_A_WEEK,
            block.timestamp - SECONDS_IN_A_WEEK
        );

        CoinCadenceDCA.DCAJobProperties memory storedJobBefore = coinCadenceDCA.getJob(jobKey);
        assert(storedJobBefore.initialized);

        coinCadenceDCA.deleteJob(jobKey);
        vm.stopPrank();

        CoinCadenceDCA.DCAJobProperties memory storedJobAfter = coinCadenceDCA.getJob(jobKey);
        assert(!storedJobAfter.initialized);
    }

    function testDeleteJobRevertsIfNoJob() public {
        bytes32 jobKey = keccak256(abi.encodePacked("test"));
        vm.expectRevert(abi.encodeWithSelector(CoinCadenceDCA.CoinCadenceDCA__JobDoesNotExist.selector, jobKey));
        coinCadenceDCA.deleteJob(jobKey);
    }

    function testDeleteJobRevertsIfNotOwner() public {
        vm.startPrank(user);
        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            SECONDS_IN_30_MINUTES,
            100000000,
            SECONDS_IN_A_WEEK,
            block.timestamp - SECONDS_IN_A_WEEK
        );

        CoinCadenceDCA.DCAJobProperties memory storedJobBefore = coinCadenceDCA.getJob(jobKey);
        assert(storedJobBefore.initialized);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CoinCadenceDCA.CoinCadenceDCA__NotOwner.selector));
        coinCadenceDCA.deleteJob(jobKey);
    }

    /////////////////
    // processJob()
    /////////////////
    function testErrorIfJobDoesNotExistWhileJobRunning() public {
        bytes32 jobKey = keccak256(abi.encodePacked("test"));
        vm.expectRevert(abi.encodeWithSelector(CoinCadenceDCA.CoinCadenceDCA__JobDoesNotExist.selector, jobKey));
        coinCadenceDCA.processJob(jobKey);
    }

    // should do some fuzz tests here

    function testErrorIfInsufficientTimeInterval() public {
        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath, user, SECONDS_IN_30_MINUTES, 100000000, SECONDS_IN_A_WEEK, block.timestamp
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CoinCadenceDCA.CoinCadenceDCA__InsufficientTimeSinceLastRun.selector, 0, SECONDS_IN_A_WEEK
            )
        );
        coinCadenceDCA.processJob(jobKey);
    }

    function testProccessJobSuccess() public {
        assertEq(usdc.balanceOf(user), 0);

        vm.startPrank(user);
        wbtc.approve(address(coinCadenceDCA), 5 ether);

        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            SECONDS_IN_30_MINUTES,
            100000000,
            SECONDS_IN_A_WEEK,
            block.timestamp - SECONDS_IN_A_WEEK
        );
        vm.stopPrank();

        coinCadenceDCA.processJob(jobKey); // this will revert if the swap fails

        console.log("usdc balance after swap: ", usdc.balanceOf(user));

        assert(usdc.balanceOf(user) > 0);
    }
}
