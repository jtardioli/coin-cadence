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

function countDecimals(x: number) {
  if (Math.floor(x) === x) {
    return 0;
  }
  return x.toString().split(".")[1].length || 0;
}

function fromReadableAmount(amount: number, decimals: number): JSBI {
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

app.get("/", async (req, res) => {
  res.send("Application is running");
});

app.get("/api/v1", async (req, res) => {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.MAINNET_RPC_URL
  );

  const router = new AlphaRouter({
    chainId: ChainId.MAINNET,
    provider: provider,
  });

  const options: SwapOptionsSwapRouter02 = {
    recipient: CurrentConfig.wallet.address,
    slippageTolerance: new Percent(50, 10_000),
    deadline: Math.floor(Date.now() / 1000 + 1800),
    type: SwapType.SWAP_ROUTER_02,
  };

  const route = await router.route(
    CurrencyAmount.fromRawAmount(
      CurrentConfig.tokens.in,
      fromReadableAmount(
        CurrentConfig.tokens.amountIn,
        CurrentConfig.tokens.in.decimals
      ).toString()
    ),
    CurrentConfig.tokens.out,
    TradeType.EXACT_INPUT,
    options
  );

  res.send(route);
});

app.listen(PORT, () => {
  console.log(`🚀 Application listening on PORT::${PORT} 🚀`);
});
