// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery-foundry/contracts/libraries/TransferHelper.sol";
import {Path} from "../lib/v3-periphery-foundry/contracts/libraries/Path.sol";

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

contract CoinCadenceDCA {
    enum Frequency {
        Weekly
    }

    ISwapRouter public immutable swapRouter;

    constructor(address _swapRouterAddress) {
        require(_swapRouterAddress != address(0), "Invalid address");
        swapRouter = ISwapRouter(_swapRouterAddress);
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

    mapping(bytes32 => DCAJobProperties) public dcaJobs;

    function setJob(DCAJobProperties memory job) external {
        bytes32 jobKey = keccak256(abi.encode(job));
        dcaJobs[jobKey] = job;
    }

    function exactInput(ISwapRouter.ExactInputParams calldata params) external returns (address amountOut) {
        // Check if the correct amount of time has passed

        address inputToken = getFirstAddress(params.path);

        TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), params.amountIn);
        TransferHelper.safeApprove(inputToken, address(swapRouter), params.amountIn);

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: params.recipient,
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum
        });

        swapRouter.exactInput(exactInputParams);

        return inputToken;
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
