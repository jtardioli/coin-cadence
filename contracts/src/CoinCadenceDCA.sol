// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;

import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "../lib/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Path} from "../lib/v3-periphery/contracts/libraries/Path.sol";

contract CoinCadenceDCA {
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

        require(!job.initialized, "Job does not exist");

        uint256 timeSinceLastRun = block.timestamp - job.prevRunTimestamp;

        require(timeSinceLastRun < job.frequencyInSeconds, "Insufficient time since last run");

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

    function _estimateAmountOut(bytes memory path, uint32 secondsAgo) public {
        address pool = uniswapFactory.getPool(_getFirstAddress(path), _getLastAddress(path), _getFee(path));
        //    (int24 tick) OracleLibrary.consult(pool, secondsAgo);
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
        require(!job.initialized, "Job does not exist");
        require(job.owner != msg.sender, "Not owner");

        delete dcaJobs[jobKey];
        emit JobDeleted(jobKey, job.owner);
    }

    function getJob(bytes32 jobKey) external view returns (DCAJobProperties memory) {
        return dcaJobs[jobKey];
    }

    function _getFirstAddress(bytes memory path) private pure returns (address) {
        address firstAddress;
        assembly {
            firstAddress := shr(96, mload(add(path, 0x20)))
        }
        return firstAddress;
    }

    function _getLastAddress(bytes memory path) public pure returns (address) {
        address lastAddress;
        assembly {
            let pathLength := mload(path)
            lastAddress := shr(96, mload(add(path, add(0x20, mul(sub(pathLength, 20), 1)))))
        }
        return lastAddress;
    }

    function _getFee(bytes memory path) public pure returns (uint24) {
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
        address nextAddress;
        assembly {
            let pathLength := mload(path)
            let offset := add(0x20, mul(sub(pathLength, 43), 1))
            nextAddress := shr(96, mload(add(path, offset)))
        }
        return nextAddress;
    }
}
