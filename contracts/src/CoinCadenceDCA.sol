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
contract CoinCadenceDCA {
    ISwapRouter public immutable swapRouter;

    constructor(address _swapRouterAddress) {
        require(_swapRouterAddress != address(0), "Invalid address");
        swapRouter = ISwapRouter(_swapRouterAddress);
    }

    // struct ExactInputParams {
    //     bytes path;
    //     address recipient;
    //     uint256 deadline;
    //     uint256 amountIn;
    //     uint256 amountOutMinimum;
    // }

    function exactInput(ISwapRouter.ExactInputParams calldata params) external returns (address amountOut) {
        address inputToken = getFirstAddress(params.path);

        TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), params.amountIn);
        // TransferHelper.safeApprove(inputToken, address(swapRouter), params.amountIn);

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

    // function swapExactInputSingle(address inputToken, address outputToken, address recipient, uint256 amountIn)
    //     external
    //     returns (uint256 amountOut)
    // {
    //     // Transfer the specified amount of inputToken to this contract.
    //     TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), amountIn);

    //     // Approve the router to spend inputToken.
    //     TransferHelper.safeApprove(inputToken, address(swapRouter), amountIn);
    //     // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    //     // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
    //         tokenIn: inputToken,
    //         tokenOut: outputToken,
    //         fee: poolFee,
    //         recipient: recipient,
    //         deadline: block.timestamp,
    //         amountIn: amountIn,
    //         amountOutMinimum: 0, // user price oracle to get this value
    //         sqrtPriceLimitX96: 0
    //     });

    //     // The call to `exactInputSingle` executes the swap.
    //     amountOut = swapRouter.exactInputSingle(params);
    // }
}
