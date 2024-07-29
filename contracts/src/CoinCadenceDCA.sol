// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "../lib/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Path} from "../lib/v3-periphery/contracts/libraries/Path.sol";
import {Quoter} from "../lib/v3-periphery/contracts/lens/Quoter.sol";

contract CoinCadenceDCA {
    struct DCAJobProperties {
        bytes path;
        address owner;
        address recipient;
        uint256 secondsToWaitForTx;
        uint256 amountIn;
        uint256 frequencyInSeconds;
        uint256 prevRunTimestamp;
        uint32 arithmeticMeanTickSecondsAgo;
        uint32 bpsSlippage;
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

        require(job.initialized, "Job does not exist");

        uint256 timeSinceLastRun = block.timestamp - job.prevRunTimestamp;

        // need to think more about if this should be > or >=
        require(timeSinceLastRun >= job.frequencyInSeconds, "Insufficient time since last run");

        address inputToken = _getFirstAddress(job.path);
        TransferHelper.safeTransferFrom(inputToken, job.owner, address(this), job.amountIn);

        uint256 estimatedAmountOut = _estimateAmountOut(job.path, job.amountIn, job.arithmeticMeanTickSecondsAgo);
        uint256 amountOutMinimum = estimatedAmountOut - (estimatedAmountOut * job.bpsSlippage / 10000);

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: job.path,
            recipient: job.recipient,
            deadline: block.timestamp + job.secondsToWaitForTx,
            amountIn: job.amountIn,
            amountOutMinimum: amountOutMinimum
        });

        swapRouter.exactInput(exactInputParams);
        job.prevRunTimestamp = job.prevRunTimestamp + job.frequencyInSeconds;
        emit JobSuccess(jobKey, job.owner);
    }

    function _estimateAmountOut(bytes memory path, uint256 amountIn, uint32 secondsAgo)
        public
        view
        returns (uint256 amountOutEstimate)
    {
        while (true) {
            bool hasMultiplePools = Path.hasMultiplePools(path);

            (address tokenIn, address tokenOut, uint24 fee) = Path.decodeFirstPool(path);
            address pool = uniswapFactory.getPool(tokenIn, tokenOut, fee);
            (int24 tick,) = OracleLibrary.consult(pool, secondsAgo);
            uint128 amountIn128 = uint128(amountIn);
            uint256 amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn128, tokenIn, tokenOut);

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                amountIn = amountOut;
                path = Path.skipToken(path);
            } else {
                return amountOut;
            }
        }
    }

    function createJob(
        bytes memory path,
        address recipient,
        uint256 secondsToWaitForTx,
        uint256 amountIn,
        uint256 frequencyInSeconds,
        uint32 arithmeticMeanTickSecondsAgo,
        uint32 bpsSlippage,
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
            arithmeticMeanTickSecondsAgo: arithmeticMeanTickSecondsAgo,
            bpsSlippage: bpsSlippage,
            initialized: true
        });

        bytes32 jobKey = keccak256(abi.encode(job));
        dcaJobs[jobKey] = job;
        emit JobCreated(jobKey, job.owner);

        return jobKey;
    }

    function deleteJob(bytes32 jobKey) external {
        DCAJobProperties memory job = dcaJobs[jobKey];
        require(job.initialized, "Job does not exist");
        require(job.owner == msg.sender, "Not owner");

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
}
