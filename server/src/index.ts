import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import {
  Percent,
  Token,
  TradeType,
  CurrencyAmount,
  ChainId,
} from "@uniswap/sdk-core";
import { ethers } from "ethers";
import {
  AlphaRouter,
  SwapType,
  type SwapOptionsSwapRouter02,
} from "@uniswap/smart-order-router";
import JSBI from "jsbi";
import { symbolName } from "typescript";
import type { Pool } from "@uniswap/v3-sdk";
import {
  fetchSwapRoute,
  getSwapPath,
  type FetchSwapRouteConfig,
} from "./services/uniswapV3";
// import { JsonRpcApiProvider } from "ethers";

const app = express();

const { PORT } = process.env;

app.use(cors({ origin: "http://localhost:3000", credentials: true }));
app.use(helmet());
app.use(express.json());
app.use(morgan("dev"));

// Sets if the example should run locally or on chain
export enum Environment {
  LOCAL,
  WALLET_EXTENSION,
  MAINNET,
}

// Inputs that configure this example to run
export interface ExampleConfig {
  env: Environment;
  rpc: {
    local: string;
    mainnet: string;
  };
  wallet: {
    address: string;
    privateKey: string;
  };
  tokens: {
    in: Token;
    amountIn: number;
    out: Token;
  };
}

export const WETH_TOKEN = new Token(
  ChainId.MAINNET, // not using SupportedChainId.MAINNET,
  "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  18,
  "WETH",
  "Wrapped Ether"
);
export const WBTC_TOKEN = new Token(
  ChainId.MAINNET, // not using SupportedChainId.MAINNET,
  "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
  8,
  "WBTC",
  "Wrapped BTC"
);
export const STETH_TOKEN = new Token(
  ChainId.MAINNET, // not using SupportedChainId.MAINNET,
  "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
  8,
  "STETH",
  "Staked Ether"
);

export const USDC_TOKEN = new Token(
  ChainId.MAINNET, // not using SupportedChainId.MAINNET
  "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
  6,
  "USDC",
  "USD//C"
);

export const CurrentConfig: ExampleConfig = {
  env: Environment.MAINNET,
  rpc: {
    local: "http://localhost:8545",
    mainnet: "",
  },
  wallet: {
    address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
    privateKey:
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  },
  tokens: {
    // in: WETH_TOKEN,
    in: WBTC_TOKEN,
    amountIn: 1,
    out: USDC_TOKEN,
  },
};

app.get("/", async (req, res) => {
  res.send("Application is running");
});

app.get("/api/v1", async (req, res) => {
  // https://uniswapv3book.com/milestone_4/path.html?highlight=path#swap-path
  // https://support.uniswap.org/hc/en-us/articles/21069524840589-What-is-a-tick-when-providing-liquidity

  const config: FetchSwapRouteConfig = {
    rpcUrl: process.env.MAINNET_RPC_URL as string,
    chainId: ChainId.MAINNET,
    recipientAddress: "0xBDb52CAF713b0371e859Fb9d6b9F9b537daB93d1",
    tokens: {
      in: WBTC_TOKEN,
      amountIn: 1,
      out: USDC_TOKEN,
    },
  };

  const path = await getSwapPath(config);

  res.send(path);
});

app.listen(PORT, () => {
  console.log(`🚀 Application listening on PORT::${PORT} 🚀`);
});
