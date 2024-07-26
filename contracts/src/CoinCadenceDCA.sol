// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../integrations/uniswap/libraries/TransferHelper.sol";
import {Path} from "../integrations/uniswap/libraries/Path.sol";

/* 
    1. Need to investigate how to not get frontrun on the swap
 */
/* 
    If I dont let the function input the swap path, then there is no way to know if the most efficient path is being used, 
    but if I do let the user input the path, then they can input any path they want, which could be inefficient or malicious.
    What happens if the pool no longer exists
 */

/* how to get all jobs for a user */

/* make sure i am emiitering the correct events */

contract CoinCadenceDCA {
    //////////////////
    // Errors    //
    /////////////////
    error CoinCadenceDCA__InsufficientTimeSinceLastRun(uint256 timeSinceLastRun, uint256 frequencyInSeconds);
    error CoinCadenceDCA__JobDoesNotExist(bytes32 jobKey);
    error CoinCadenceDCA__JobAlreadyExists(bytes32 jobKey);
    error CoinCadenceDCA__NotOwner();
    error CoinCadenceDCA__InvalidAddress();

    ////////////////////////
    // Type               //
    ////////////////////////
    enum Frequency {
        Weekly,
        BiWeekly
    }

    struct DCAJobProperties {
        bytes path;
        address owner;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        Frequency frequency;
        uint256 prevRunTimestamp;
        bool initialized;
    }

    ////////////////////////
    // State Variables    //
    ////////////////////////
    ISwapRouter public immutable swapRouter;
    mapping(Frequency => uint256) private frequencyToSeconds;
    mapping(bytes32 => DCAJobProperties) private dcaJobs;

    ////////////////////////
    // Events            //
    ////////////////////////
    event JobCreated(bytes32 indexed jobKey, address indexed owner);
    event JobDeleted(bytes32 indexed jobKey, address indexed owner);
    event JobSuccess(bytes32 indexed jobKey, address indexed owner);
    event JobFailed(bytes32 indexed jobKey, address indexed owner, string reason);

    //////////////////
    // Modifiers    //
    /////////////////

    constructor(address _swapRouterAddress) {
        if (_swapRouterAddress == address(0)) {
            revert CoinCadenceDCA__InvalidAddress();
        }

        swapRouter = ISwapRouter(_swapRouterAddress);

        // Initialize the mapping with the number of seconds for each frequency
        frequencyToSeconds[Frequency.Weekly] = 7 * 24 * 60 * 60; // 1 week in seconds
        frequencyToSeconds[Frequency.BiWeekly] = 7 * 24 * 60 * 60 * 2; // 2 week in seconds
    }

    //////////////////////////
    // External Functions   //
    /////////////////////////
    function processJob(bytes32 jobKey) external {
        DCAJobProperties memory job = dcaJobs[jobKey];

        if (!job.initialized) {
            emit JobFailed(jobKey, job.owner, "Job does not exist");
            revert CoinCadenceDCA__JobDoesNotExist(jobKey);
        }

        uint256 timeSinceLastRun = block.timestamp - job.prevRunTimestamp;
        uint256 frequencyInSeconds = frequencyToSeconds[job.frequency];

        if (timeSinceLastRun < frequencyInSeconds) {
            emit JobFailed(jobKey, job.owner, "Insufficient time since last run");
            revert CoinCadenceDCA__InsufficientTimeSinceLastRun(timeSinceLastRun, frequencyInSeconds);
        }

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: job.path,
            recipient: job.recipient,
            deadline: job.deadline,
            amountIn: job.amountIn,
            amountOutMinimum: job.amountOutMinimum
        });

        try swapRouter.exactInput(exactInputParams) {
            job.prevRunTimestamp = job.prevRunTimestamp + frequencyInSeconds;
            emit JobSuccess(jobKey, job.owner);
        } catch (bytes memory lowLevelData) {
            emit JobFailed(jobKey, job.owner, "Swap failed: low level error");
        }
    }

    function createJob(
        bytes memory path,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMinimum,
        Frequency frequency,
        uint256 prevRunTimestamp
    ) external returns (bytes32) {
        CoinCadenceDCA.DCAJobProperties memory job = CoinCadenceDCA.DCAJobProperties({
            path: path,
            owner: msg.sender,
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            frequency: frequency,
            prevRunTimestamp: prevRunTimestamp,
            initialized: true
        });

        bytes32 jobKey = keccak256(abi.encode(job));
        dcaJobs[jobKey] = job;
        emit JobCreated(jobKey, job.owner);

        return jobKey;
    }

    function deleteJob(bytes32 jobKey) external returns (bytes32) {
        DCAJobProperties memory job = dcaJobs[jobKey];
        if (!job.initialized) {
            revert CoinCadenceDCA__JobDoesNotExist(jobKey);
        }

        if (job.owner != msg.sender) {
            revert CoinCadenceDCA__NotOwner();
        }

        delete dcaJobs[jobKey];
        emit JobDeleted(jobKey, job.owner);
    }

    function getJob(bytes32 jobKey) external view returns (DCAJobProperties memory) {
        return dcaJobs[jobKey];
    }

    function getFrequencyToSeconds(Frequency frequency) external view returns (uint256) {
        return frequencyToSeconds[frequency];
    }

    //////////////////////////
    // Internal Functions   //
    /////////////////////////

    function exactInputSwap(ISwapRouter.ExactInputParams calldata params) private {
        address inputToken = getFirstAddress(params.path);

        TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), params.amountIn);
        TransferHelper.safeApprove(inputToken, address(swapRouter), params.amountIn);

        swapRouter.exactInput(params);
    }

    function getFirstAddress(bytes calldata path) private pure returns (address) {
        require(path.length >= 20, "Path too short");
        address firstAddress;
        assembly {
            firstAddress := shr(96, calldataload(add(path.offset, 0)))
        }
        return firstAddress;
    }
}
