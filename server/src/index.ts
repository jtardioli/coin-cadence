import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import { Token, ChainId } from "@uniswap/sdk-core";
import { getSwapPath, type FetchSwapRouteConfig } from "./services/uniswapV3";

const app = express();

const { PORT } = process.env;

app.use(cors({ origin: "http://localhost:3000", credentials: true }));
app.use(helmet());
app.use(express.json());
app.use(morgan("dev"));

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
