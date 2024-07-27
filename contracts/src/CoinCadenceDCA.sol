// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "../integrations/uniswap/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "../integrations/uniswap/interfaces/IUniswapV3Factory.sol";
import {TransferHelper} from "../integrations/uniswap/libraries/TransferHelper.sol";
import {Path} from "../integrations/uniswap/libraries/Path.sol";

contract CoinCadenceDCA {
    error CoinCadenceDCA__InsufficientTimeSinceLastRun(uint256 timeSinceLastRun, uint256 frequencyInSeconds);
    error CoinCadenceDCA__JobDoesNotExist(bytes32 jobKey);
    error CoinCadenceDCA__JobAlreadyExists(bytes32 jobKey);
    error CoinCadenceDCA__NotOwner();
    error CoinCadenceDCA__InvalidAddress();
    error CoinCadenceDCA__PathToShort();

    struct DCAJobProperties {
        bytes path;
        address owner;
        address recipient;
        uint256 secondsToWaitForTx;
        uint256 amountIn;
        uint256 frequencyInSeconds;
        uint256 prevRunTimestamp;
        bool initialized;
    }

    ISwapRouter public immutable swapRouter;
    IUniswapV3Factory public immutable uniswapFactory;
    mapping(bytes32 => DCAJobProperties) private dcaJobs;

    event JobCreated(bytes32 indexed jobKey, address indexed owner);
    event JobDeleted(bytes32 indexed jobKey, address indexed owner);
    event JobSuccess(bytes32 indexed jobKey, address indexed owner);

    constructor(address _swapRouterAddress, address _factory) {
        swapRouter = ISwapRouter(_swapRouterAddress);
        uniswapFactory = IUniswapV3Factory(_factory);
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
            // @audit can't use the same amountOutMinimum for all jobs because price will change
            //        if the price goes up, the swap will fail and if the price goes down,
            //        the user will get less than it's worth
            amountOutMinimum: 0
        });

        swapRouter.exactInput(exactInputParams);
        job.prevRunTimestamp = job.prevRunTimestamp + job.frequencyInSeconds;
        emit JobSuccess(jobKey, job.owner);
    }

    function _estimateAmountOut(bytes memory path) public {
        address pool = uniswapFactory.getPool(_getFirstAddress(path), _getLastAddress(path), _getFee(path));
    }

    function createJob(
        bytes memory path,
        address recipient,
        uint256 secondsToWaitForTx,
        uint256 amountIn,
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
            frequencyInSeconds: frequencyInSeconds,
            prevRunTimestamp: prevRunTimestamp,
            initialized: true
        });

        bytes32 jobKey = keccak256(abi.encode(job));
        dcaJobs[jobKey] = job;
        emit JobCreated(jobKey, job.owner);

        return jobKey;
    }

    function deleteJob(bytes32 jobKey) external {
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
        if (path.length < 20) {
            revert CoinCadenceDCA__PathToShort();
        }
        address firstAddress;
        assembly {
            firstAddress := shr(96, mload(add(path, 0x20)))
        }
        return firstAddress;
    }

    function _getLastAddress(bytes memory path) public pure returns (address) {
        if (path.length < 20) {
            revert CoinCadenceDCA__PathToShort();
        }
        address lastAddress;
        assembly {
            let pathLength := mload(path)
            lastAddress := shr(96, mload(add(path, add(0x20, mul(sub(pathLength, 20), 1)))))
        }
        return lastAddress;
    }

    function _getFee(bytes memory path) public pure returns (uint24) {
        if (path.length < 43) {
            revert CoinCadenceDCA__PathToShort();
        }
        uint24 fee;
        assembly {
            let pathLength := mload(path)
            let offset := add(0x20, mul(sub(pathLength, 43), 1))
            offset := add(offset, 20) // skip the first address
            fee := mload(add(path, offset))
            fee := shr(232, fee)
        }
        return uint24(fee);
    }

    function _getSecondLastAddress(bytes memory path) public pure returns (address) {
        if (path.length < 43) {
            revert CoinCadenceDCA__PathToShort();
        }
        address nextAddress;
        assembly {
            let pathLength := mload(path)
            let offset := add(0x20, mul(sub(pathLength, 43), 1))
            nextAddress := shr(96, mload(add(path, offset)))
        }
        return nextAddress;
    }
}
