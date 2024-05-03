// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";

contract CoinCadenceDCA {
    ISwapRouter router;

    /**
     *
     * How will we charge users for the gas of the swap?
     * We need to be able to set a limit
     *
     * @param from address to take the input token from
     * @param to address to send the output token to
     * @param inputToken address of the token to be used as input
     * @param outputToken address of the token to be used as output
     * @param amountInputToken amount of input token to be used
     * @param slippage slippage in percentage
     * @param gasLimit gas limit for the transaction
     */
    function investFromWallet(
        address from,
        address to,
        address inputToken,
        address outputToken,
        uint256 amountInputToken,
        uint256 slippage,
        uint256 gasLimit
    ) external payable {}
}
