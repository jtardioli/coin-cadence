// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../integrations/uniswap/libraries/TransferHelper.sol";
import {Path} from "../integrations/uniswap/libraries/Path.sol";

contract CoinCadenceDCA {
    error CoinCadenceDCA__InsufficientTimeSinceLastRun(uint256 timeSinceLastRun, uint256 frequencyInSeconds);
    error CoinCadenceDCA__JobDoesNotExist(bytes32 jobKey);
    error CoinCadenceDCA__JobAlreadyExists(bytes32 jobKey);
    error CoinCadenceDCA__NotOwner();
    error CoinCadenceDCA__InvalidAddress();

    struct DCAJobProperties {
        bytes path;
        address owner;
        address recipient;
        uint256 secondsToWaitForTx;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint256 frequencyInSeconds;
        uint256 prevRunTimestamp;
        bool initialized;
    }

    ISwapRouter public immutable swapRouter;
    mapping(bytes32 => DCAJobProperties) private dcaJobs;

    event JobCreated(bytes32 indexed jobKey, address indexed owner);
    event JobDeleted(bytes32 indexed jobKey, address indexed owner);
    event JobSuccess(bytes32 indexed jobKey, address indexed owner);

    constructor(address _swapRouterAddress) {
        if (_swapRouterAddress == address(0)) {
            revert CoinCadenceDCA__InvalidAddress();
        }

        swapRouter = ISwapRouter(_swapRouterAddress);
    }

    function processJob(bytes32 jobKey) external {
        DCAJobProperties memory job = dcaJobs[jobKey];

        if (!job.initialized) {
            revert CoinCadenceDCA__JobDoesNotExist(jobKey);
        }

        uint256 timeSinceLastRun = block.timestamp - job.prevRunTimestamp;

        if (timeSinceLastRun < job.frequencyInSeconds) {
            revert CoinCadenceDCA__InsufficientTimeSinceLastRun(timeSinceLastRun, job.frequencyInSeconds);
        }

        address inputToken = _getFirstAddress(job.path);
        TransferHelper.safeTransferFrom(inputToken, job.owner, address(this), job.amountIn);

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: job.path,
            recipient: job.recipient,
            deadline: block.timestamp + job.secondsToWaitForTx,
            amountIn: job.amountIn,
            amountOutMinimum: job.amountOutMinimum
        });

        swapRouter.exactInput(exactInputParams);
        job.prevRunTimestamp = job.prevRunTimestamp + job.frequencyInSeconds;
        emit JobSuccess(jobKey, job.owner);
    }

    function createJob(
        bytes memory path,
        address recipient,
        uint256 secondsToWaitForTx,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 frequencyInSeconds,
        uint256 prevRunTimestamp
    ) external returns (bytes32) {
        address inputToken = _getFirstAddress(path);
        TransferHelper.safeApprove(inputToken, address(swapRouter), type(uint256).max);

        CoinCadenceDCA.DCAJobProperties memory job = CoinCadenceDCA.DCAJobProperties({
            path: path,
            owner: msg.sender,
            recipient: recipient,
            secondsToWaitForTx: secondsToWaitForTx,
            amountIn: amountIn,
            // @audit can't use the same amountOutMinimum for all jobs because price will change
            //        if the price goes up, the swap will fail and if the price goes down,
            //        the user will get less than it's worth
            amountOutMinimum: amountOutMinimum,
            frequencyInSeconds: frequencyInSeconds,
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

    function _getFirstAddress(bytes memory path) private pure returns (address) {
        require(path.length >= 20, "Path too short");
        address firstAddress;
        assembly {
            firstAddress := shr(96, mload(add(path, 0x20)))
        }
        return firstAddress;
    }
}
