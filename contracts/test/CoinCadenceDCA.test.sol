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
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.Weekly,
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly)
        );
        vm.stopPrank();

        CoinCadenceDCA.DCAJobProperties memory storedJob = coinCadenceDCA.getJob(jobKey);

        assertEq(storedJob.path, wbtcToUsdcPath);
        assertEq(storedJob.owner, user);
        assertEq(storedJob.recipient, user);
        assertEq(storedJob.deadline, block.timestamp + 5 * 60);
        assertEq(storedJob.amountIn, 100000000);
        assertEq(storedJob.amountOutMinimum, 0);
        assertEq(keccak256(abi.encode(storedJob.frequency)), keccak256(abi.encode(CoinCadenceDCA.Frequency.Weekly)));
        assertEq(
            storedJob.prevRunTimestamp,
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly)
        );
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
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.Weekly,
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly)
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
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.Weekly,
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly)
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

    function testErrorIfInsufficientTimeIntervalForWeekly() public {
        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.Weekly,
            block.timestamp
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                CoinCadenceDCA.CoinCadenceDCA__InsufficientTimeSinceLastRun.selector,
                0,
                coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly)
            )
        );
        coinCadenceDCA.processJob(jobKey);
    }

    function testErrorIfInsufficientTimeIntervalForBiWeekly() public {
        uint256 prevRunTimestamp =
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.Weekly);

        bytes32 jobKey = coinCadenceDCA.createJob(
            wbtcToUsdcPath,
            user,
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.BiWeekly,
            prevRunTimestamp
        );
        uint256 timeSinceLastRun = block.timestamp - prevRunTimestamp;

        vm.expectRevert(
            abi.encodeWithSelector(
                CoinCadenceDCA.CoinCadenceDCA__InsufficientTimeSinceLastRun.selector,
                timeSinceLastRun,
                coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.BiWeekly)
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
            block.timestamp + 5 * 60,
            100000000,
            0,
            CoinCadenceDCA.Frequency.Weekly,
            block.timestamp - coinCadenceDCA.getFrequencyToSeconds(CoinCadenceDCA.Frequency.BiWeekly)
        );
        vm.stopPrank();

        coinCadenceDCA.processJob(jobKey); // this will revert if the swap fails

        assert(usdc.balanceOf(user) > 0);
    }
}
