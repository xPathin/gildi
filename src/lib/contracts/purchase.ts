import { config, publicClient } from '$lib/wagmi/config';
import { ADDRESSES, AggregatorAbi, Erc20Abi, ExchangeAbi } from './addresses';
import { writeContract, waitForTransactionReceipt } from '@wagmi/core';
import type { Address } from 'viem';

export type EstimatePurchaseResult = {
  sourceNeeded: bigint;
  releaseCurrency: Address;
  totalPriceUsd: bigint;
  // quoteRoute omitted in typing for brevity
};

export async function getAllowedPurchaseTokens(): Promise<Address[]> {
  const tokens = (await publicClient.readContract({
    abi: AggregatorAbi,
    address: ADDRESSES.aggregator,
    functionName: 'getAllowedPurchaseTokens',
    args: [],
  })) as Address[];
  return tokens;
}

export async function estimatePurchase(
  releaseId: bigint,
  amount: bigint,
  buyer: Address,
  sourceToken: Address
): Promise<EstimatePurchaseResult> {
  const res = await publicClient.readContract({
    abi: AggregatorAbi,
    address: ADDRESSES.aggregator,
    functionName: 'estimatePurchase',
    args: [releaseId, amount, buyer, sourceToken],
  });
  return {
    sourceNeeded: res[0],
    releaseCurrency: res[1],
    totalPriceUsd: res[3],
  };
}

export async function canBuy(
  releaseId: bigint,
  buyer: Address
): Promise<{ buyAllowed: boolean; maxBuyAmount: bigint }> {
  const res = await publicClient.readContract({
    abi: ExchangeAbi,
    address: ADDRESSES.exchange,
    functionName: 'canBuy',
    args: [releaseId, buyer],
  });
  return { buyAllowed: res[0], maxBuyAmount: res[1] };
}

export async function getErc20Meta(
  token: Address
): Promise<{ name: string; symbol: string; decimals: number }> {
  const [name, symbol, decimals] = await Promise.all([
    publicClient.readContract({
      abi: Erc20Abi,
      address: token,
      functionName: 'name',
      args: [],
    }) as Promise<string>,
    publicClient.readContract({
      abi: Erc20Abi,
      address: token,
      functionName: 'symbol',
      args: [],
    }) as Promise<string>,
    publicClient.readContract({
      abi: Erc20Abi,
      address: token,
      functionName: 'decimals',
      args: [],
    }) as Promise<number>,
  ]);
  return { name, symbol, decimals };
}

export async function getAllowance(
  token: Address,
  owner: Address,
  spender: Address
): Promise<bigint> {
  const allowance = await publicClient.readContract({
    abi: Erc20Abi,
    address: token,
    functionName: 'allowance',
    args: [owner, spender],
  });
  return allowance;
}

export async function getErc20Balance(
  token: Address,
  owner: Address
): Promise<bigint> {
  const bal = await publicClient.readContract({
    abi: Erc20Abi,
    address: token,
    functionName: 'balanceOf',
    args: [owner],
  });
  return bal;
}

export async function approve(
  token: Address,
  spender: Address,
  amount: bigint
) {
  const hash = await writeContract(config, {
    abi: Erc20Abi,
    address: token,
    functionName: 'approve',
    args: [spender, amount],
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}

export async function purchase(
  releaseId: bigint,
  amount: bigint,
  sourceToken: Address,
  sourceMaxAmount: bigint
) {
  const hash = await writeContract(config, {
    abi: AggregatorAbi,
    address: ADDRESSES.aggregator,
    functionName: 'purchase',
    args: [releaseId, amount, sourceToken, sourceMaxAmount],
    value: 0n,
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}
