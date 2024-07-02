import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import { Percent, Token } from "@uniswap/sdk-core";
import { ethers } from "ethers";
import {
  AlphaRouter,
  SwapType,
  type SwapOptionsSwapRouter02,
} from "@uniswap/smart-order-router";
import JSBI from "jsbi";
// import { JsonRpcApiProvider } from "ethers";

const app = express();

const { PORT } = process.env;

app.use(cors({ origin: "http://localhost:3000", credentials: true }));
app.use(helmet());
app.use(express.json());
app.use(morgan("dev"));

// interface ExampleConfig {
//   env: Environment
//   rpc: {
//     local: string
//     mainnet: string
//   }
//   wallet: {
//     address: string
//     privateKey: string
//   }
//   tokens: {
//     in: Token
//     amountIn: number
//     out: Token
//   }
// }

// export const CurrentConfig: ExampleConfig = {...}

export function fromReadableAmount(amount: number, decimals: number): JSBI {
  const extraDigits = Math.pow(10, countDecimals(amount));
  const adjustedAmount = amount * extraDigits;
  return JSBI.divide(
    JSBI.multiply(
      JSBI.BigInt(adjustedAmount),
      JSBI.exponentiate(JSBI.BigInt(10), JSBI.BigInt(decimals))
    ),
    JSBI.BigInt(extraDigits)
  );
}

app.get("/", (req, res) => {
  res.send("Application is running");
});

app.get("/api/v1", (req, res) => {
  const rpcUrl = process.env.MAINNET_RPC_URL;
  const mainnetChainId = 1;

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const router = new AlphaRouter({
    chainId: mainnetChainId,
    provider,
  });

  const options: SwapOptionsSwapRouter02 = {
    recipient: "0xBDb52CAF713b0371e859Fb9d6b9F9b537daB93d1",
    slippageTolerance: new Percent(50, 10_000),
    deadline: Math.floor(Date.now() / 1000 + 1800),
    type: SwapType.SWAP_ROUTER_02,
  };

  const rawTokenAmountIn: JSBI = fromReadableAmount(
    CurrentConfig.currencies.amountIn,
    CurrentConfig.currencies.in.decimals
  );

  const route = await router.route(
    CurrencyAmount.fromRawAmount(CurrentConfig.currencies.in, rawTokenAmountIn),
    CurrentConfig.currencies.out,
    TradeType.EXACT_INPUT,
    options
  );

  res.send("Application is running");
});

app.listen(PORT, () => {
  console.log(`🚀 Application listening on PORT::${PORT} 🚀`);
});
