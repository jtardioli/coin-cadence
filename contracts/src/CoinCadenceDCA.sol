// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery-foundry/contracts/libraries/TransferHelper.sol";

// DONT FOR GET TO LOOK INTO PRICE ORACLE TO NOT GET FRONT RUN
contract CoinCadenceDCA {
    ISwapRouter public immutable swapRouter;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    /// @notice swapExactInputSingle swaps a fixed amount of inputToken for a maximum possible amount of outputToken
    /// using the inputToken/outputToken 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its inputToken for this function to succeed.
    /// @param amountIn The exact amount of inputToken that will be swapped for outputToken.
    /// @return amountOut The amount of outputToken received.
    function swapExactInputSingle(address inputToken, address outputToken, address recipient, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        // Transfer the specified amount of inputToken to this contract.
        TransferHelper.safeTransferFrom(inputToken, msg.sender, address(this), amountIn);

        // Approve the router to spend inputToken.
        TransferHelper.safeApprove(inputToken, address(swapRouter), amountIn);
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: inputToken,
            tokenOut: outputToken,
            fee: poolFee,
            recipient: recipient,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }
}
