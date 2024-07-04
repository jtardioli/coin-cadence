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

export const V3_SWAP_ROUTER_ADDRESS =
  "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
export const WETH_CONTRACT_ADDRESS =
  "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

// Currencies and Tokens

export const USDC_TOKEN = new Token(
  ChainId.MAINNET,
  "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
  6,
  "USDC",
  "USD//C"
);

export const DAI_TOKEN = new Token(
  ChainId.MAINNET,
  "0x6B175474E89094C44Da98b954EedeAC495271d0F",
  18,
  "DAI",
  "Dai Stablecoin"
);

export const WETH_TOKEN = new Token(
  ChainId.MAINNET,
  "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  18,
  "WETH",
  "Wrapped Ether"
);

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

export const CurrentConfig: ExampleConfig = {
  env: Environment.LOCAL,
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
    in: WETH_TOKEN,
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

app.get("/", async (req, res) => {
  res.send("Application is running");
});

app.get("/api/v1", async (req, res) => {
  const rpcUrl = process.env.MAINNET_RPC_URL;

  console.log({ rpcUrl });

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const router = new AlphaRouter({
    chainId: ChainId.MAINNET,
    provider: provider,
  });

  const options: SwapOptionsSwapRouter02 = {
    recipient: "0xBDb52CAF713b0371e859Fb9d6b9F9b537daB93d1",
    slippageTolerance: new Percent(50, 10_000),
    deadline: Math.floor(Date.now() / 1000 + 1800),
    type: SwapType.SWAP_ROUTER_02,
  };

  const readableAmount = fromReadableAmount(
    CurrentConfig.tokens.amountIn,
    CurrentConfig.tokens.in.decimals
  ).toString();

  const amount = CurrencyAmount.fromRawAmount(
    CurrentConfig.tokens.in,
    readableAmount
  );

  try {
    const route = await router.route(
      amount,
      CurrentConfig.tokens.out,
      TradeType.EXACT_INPUT,
      options
    );

    if (!route || !route.methodParameters) {
      console.log("No route found");
    }

    console.log({ route });
  } catch (error) {
    console.log({ error });
  }

  // const wallet = new ethers.Wallet(privateKey, provider);
  // const tokenContract = new ethers.Contract(
  //   CurrentConfig.tokens.in.address,
  //   ERC20ABI,
  //   wallet
  // );
  // const tokenApproval = await tokenContract.approve(
  //   V3_SWAP_ROUTER_ADDRESS,
  //   ethers.BigNumber.from(rawTokenAmountIn.toString())
  // );

  // const txRes = await wallet.sendTransaction({
  //   data: route.methodParameters.calldata,
  //   to: V3_SWAP_ROUTER_ADDRESS,
  //   value: route.methodParameters.value,
  //   from: wallet.address,
  //   maxFeePerGas: MAX_FEE_PER_GAS,
  //   maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
  // })

  res.send("Application is running");
});

app.listen(PORT, () => {
  console.log(`🚀 Application listening on PORT::${PORT} 🚀`);
});
