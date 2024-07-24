// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../integrations/uniswap/libraries/TransferHelper.sol";
import {Path} from "../integrations/uniswap/libraries/Path.sol";

/* 
    1. Need to investigate how to not get frontrun on the swap
    2. Does the exact input single function work if no pool exists for the token pair?
    3. Handle if user did not approve enough of the token
    4. handle if user does not have enough balance in thier wallet
 */

/* 
    If I dont let the function input the swap path, then there is no way to know if the most efficient path is being used, 
    but if I do let the user input the path, then they can input any path they want, which could be inefficient or malicious.
    What happens if the pool no longer exists
 */
/* 
    Make sure to look into not being able to send other people money. I think the sender should always be the msg.sender
    That created the job
 */

/* 
    Could think about a way to make the frequencies allowed dynamic
 */

error CoinCadenceDCA__InsufficientTimeInterval(uint256 timeSinceLastRun, uint256 frequencyInSeconds);

contract CoinCadenceDCA {
    enum Frequency {
        Weekly
    }

    ISwapRouter public immutable swapRouter;

    constructor(address _swapRouterAddress) {
        require(_swapRouterAddress != address(0), "Invalid address");
        swapRouter = ISwapRouter(_swapRouterAddress);

        // Initialize the mapping with the number of seconds for each frequency
        frequencyToSeconds[Frequency.Weekly] = 7 * 24 * 60 * 60; // 1 week in seconds
    }

    struct DCAJobProperties {
        bytes path;
        address sender;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        Frequency frequency;
        uint256 lastRunTimestamp;
        uint256 startTimestamp;
    }

    mapping(Frequency => uint256) public frequencyToSeconds;

    function getSeconds(Frequency frequency) public view returns (uint256) {
        return frequencyToSeconds[frequency];
    }

    mapping(bytes32 => DCAJobProperties) public dcaJobs;

    function getJob(bytes32 jobKey) external view returns (DCAJobProperties memory) {
        return dcaJobs[jobKey];
    }

    function setJob(DCAJobProperties memory job) external {
        bytes32 jobKey = keccak256(abi.encode(job));
        dcaJobs[jobKey] = job;
    }

    function exactInput(ISwapRouter.ExactInputParams calldata params) external returns (address amountOut) {
        // Check if the correct amount of time has passed

        address inputToken = getFirstAddress(params.path);

        TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), params.amountIn);
        TransferHelper.safeApprove(inputToken, address(swapRouter), params.amountIn);

        swapRouter.exactInput(params);

        return inputToken;
    }

    function processJob(bytes32 jobKey) external {
        DCAJobProperties memory job = dcaJobs[jobKey];

        uint256 timeSinceLastRun = block.timestamp - job.lastRunTimestamp;
        uint256 frequencyInSeconds = frequencyToSeconds[job.frequency];

        if (timeSinceLastRun < frequencyInSeconds) {
            revert CoinCadenceDCA__InsufficientTimeInterval(timeSinceLastRun, frequencyInSeconds);
        }

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: job.path,
            recipient: job.recipient,
            deadline: job.deadline,
            amountIn: job.amountIn,
            amountOutMinimum: job.amountOutMinimum
        });
        swapRouter.exactInput(exactInputParams);

        job.lastRunTimestamp = job.lastRunTimestamp + frequencyInSeconds;
    }

    function getFirstAddress(bytes calldata path) public pure returns (address) {
        require(path.length >= 20, "Path too short");
        address firstAddress;
        assembly {
            firstAddress := shr(96, calldataload(add(path.offset, 0)))
        }
        return firstAddress;
    }
}
