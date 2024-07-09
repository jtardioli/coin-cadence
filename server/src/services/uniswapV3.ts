import {
  ChainId,
  CurrencyAmount,
  Percent,
  Token,
  TradeType,
} from "@uniswap/sdk-core";
import {
  AlphaRouter,
  SwapType,
  type SwapOptionsSwapRouter02,
  type SwapRoute,
} from "@uniswap/smart-order-router";
import { fromReadableAmount } from "../libs/math";
import type { Pool } from "@uniswap/v3-sdk";
import { concatBytes, numberToBytes3 } from "../libs/bytes";
import { ethers } from "ethers";

export class UniswapV3ServiceError extends Error {
  constructor(message?: string) {
    super(message);
  }
}

export type FetchSwapRouteConfig = {
  rpcUrl: string;
  chainId: number;
  recipientAddress: string;
  tokens: {
    in: Token;
    amountIn: number;
    out: Token;
  };
};

export const PoolFeeToTickSpacing = {
  100: 1,
  500: 10,
  3000: 60,
  10000: 200,
};

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

const myConfig: FetchSwapRouteConfig = {
  rpcUrl: process.env.MAINNET_RPC_URL as string,
  chainId: ChainId.MAINNET,
  recipientAddress: "0xBDb52CAF713b0371e859Fb9d6b9F9b537daB93d1",
  tokens: {
    in: WBTC_TOKEN,
    amountIn: 1,
    out: USDC_TOKEN,
  },
};

export async function fetchSwapRoute(
  config: FetchSwapRouteConfig
): Promise<SwapRoute> {
  try {
    const provider = new ethers.providers.JsonRpcProvider(config.rpcUrl);

    const router = new AlphaRouter({
      chainId: config.chainId,
      provider: provider,
    });

    const options: SwapOptionsSwapRouter02 = {
      recipient: config.recipientAddress,
      slippageTolerance: new Percent(50, 10_000),
      deadline: Math.floor(Date.now() / 1000 + 1800),
      type: SwapType.SWAP_ROUTER_02,
    };

    const route = await router.route(
      CurrencyAmount.fromRawAmount(
        config.tokens.in,
        fromReadableAmount(
          config.tokens.amountIn,
          config.tokens.in.decimals
        ).toString()
      ),
      config.tokens.out,
      TradeType.EXACT_INPUT,
      options
    );

    if (!route || !route.methodParameters) {
      console.error("UniswapV3ServiceError::fetchSwapRoute(): No route found");
      throw new UniswapV3ServiceError(
        "UniswapV3ServiceError::fetchSwapRoute(): No route found"
      );
    }

    return route;
  } catch (err) {
    console.error(
      "UniswapV3ServiceError::fetchSwapRoute(): Error fetching swap route:",
      err
    );
    throw new UniswapV3ServiceError("Error fetching swap route");
  }
}

function processRoute(route: SwapRoute) {
  const poolsByTokenPair: Record<string, Pool> = {};
  route.trade.swaps[0].route.pools.forEach((pool) => {
    const tokenPairKey = `${pool.token0.address}-${pool.token1.address}`;
    const reversedTokenPairKey = `${pool.token1.address}-${pool.token0.address}`;

    poolsByTokenPair[tokenPairKey] = pool as Pool;
    poolsByTokenPair[reversedTokenPairKey] = pool as Pool;
  });

  //@ts-expect-error UniswapV3 SDK types are not up to date
  const tokenPath = route.trade.swaps[0].route.tokenPath;
  const pathParts = [];
  for (let i = 0; i < tokenPath.length; i++) {
    const lastToken = i === tokenPath.length - 1;

    const token1 = tokenPath[i];
    const token2 = tokenPath[i + 1];
    pathParts.push(token1.address);

    if (!lastToken) {
      const tokenPairKey = `${token1.address}-${token2.address}`;
      const pool = poolsByTokenPair[tokenPairKey];
      pathParts.push(numberToBytes3(PoolFeeToTickSpacing[pool.fee]));
    }
  }

  const path = concatBytes(pathParts);
  return path;
}

export async function getSwapPath(config: FetchSwapRouteConfig) {
  const route = await fetchSwapRoute(config);
  const path = processRoute(route);
  return path;
}
