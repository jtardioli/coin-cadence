// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {ISwapRouter} from "../lib/v3-periphery-foundry/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery-foundry/contracts/libraries/TransferHelper.sol";

/* 
    1. Need to investigate how to not get frontrun on the swap
    2. Does the exact input single function work if no pool exists for the token pair?
    3. Handle if user did not approve enough of the token
    4. handle if user does not have enough balance in thier wallet
 */
contract CoinCadenceDCA {}
