import { config, publicClient } from '$lib/wagmi/config';
import { writeContract, waitForTransactionReceipt } from '@wagmi/core';
import {
  ADDRESSES,
  ExchangeAbi,
  OrderBookAbi,
  ManagerAbi,
  ShareTokenAbi,
} from './addresses';
import type { Address } from 'viem';

export type Listing = {
  id: bigint;
  releaseId: bigint;
  seller: Address;
  pricePerItem: bigint; // USD cents
  payoutCurrency: Address;
  quantity: bigint;
  slippageBps?: number;
  createdAt?: bigint;
  modifiedAt?: bigint;
  nextListingId?: bigint;
  prevListingId?: bigint;
  fundsReceiver: Address;
};

export async function getFloorPrice(releaseId: bigint) {
  const [ordered] = await publicClient.readContract({
    abi: OrderBookAbi,
    address: ADDRESSES.orderBook,
    functionName: 'getOrderedListings',
    args: [releaseId, 0n, 1n],
  });
  return ordered?.[0]?.pricePerItem as bigint | undefined;
}

export async function getListedQuantities(releaseId: bigint): Promise<bigint> {
  const res = await publicClient.readContract({
    abi: OrderBookAbi,
    address: ADDRESSES.orderBook,
    functionName: 'listedQuantities',
    args: [releaseId],
  });
  return res;
}

export async function getTotalShareSupply(releaseId: bigint): Promise<bigint> {
  const res = await publicClient.readContract({
    abi: ShareTokenAbi,
    address: ADDRESSES.shareToken,
    functionName: 'totalSupply',
    args: [releaseId],
  });
  return res as bigint;
}

export async function getOrderedListingsForRelease(
  releaseId: bigint,
  cursor: bigint = 0n,
  limit: bigint = 25n
): Promise<{ listings: Listing[]; cursor: bigint }> {
  const [ordered, nextCursor] = (await publicClient.readContract({
    abi: OrderBookAbi,
    address: ADDRESSES.orderBook,
    functionName: 'getOrderedListings',
    args: [releaseId, cursor, limit],
  })) as unknown as [Listing[], bigint];
  return { listings: ordered || [], cursor: nextCursor ?? 0n };
}

export async function getMarketplaceCurrency(): Promise<Address> {
  const env = await publicClient.readContract({
    abi: ExchangeAbi,
    address: ADDRESSES.exchange,
    functionName: 'getAppEnvironment',
    args: [],
  });
  const settings = env.settings;
  const marketplaceCurrency = settings?.marketplaceCurrency;
  return marketplaceCurrency;
}

// Slippage is handled by contract default; we do not pass slippage params from UI.

export async function getListingsOfSeller(seller: Address): Promise<Listing[]> {
  const res = await publicClient.readContract({
    abi: OrderBookAbi,
    address: ADDRESSES.orderBook,
    functionName: 'getListingsOfSeller',
    args: [seller],
  });
  return res as unknown as Listing[];
}

export async function getListing(listingId: bigint): Promise<Listing> {
  const res = await publicClient.readContract({
    abi: OrderBookAbi,
    address: ADDRESSES.orderBook,
    functionName: 'getListing',
    args: [listingId],
  });
  return res as unknown as Listing;
}

export async function getAvailableBalance(
  tokenId: bigint,
  account: Address
): Promise<bigint> {
  const res = await publicClient.readContract({
    abi: ManagerAbi,
    address: ADDRESSES.manager,
    functionName: 'getAvailableBalance',
    args: [tokenId, account],
  });
  return res as bigint;
}

export async function createListing(params: {
  releaseId: bigint;
  seller: Address;
  pricePerItem: bigint; // USD cents
  quantity: bigint;
  payoutCurrency: Address;
  fundsReceiver: Address;
}) {
  const {
    releaseId,
    seller,
    pricePerItem,
    quantity,
    payoutCurrency,
    fundsReceiver,
  } = params;
  const hash = await writeContract(config, {
    abi: ExchangeAbi,
    address: ADDRESSES.exchange,
    functionName: 'createListing',
    args: [
      releaseId,
      seller,
      pricePerItem,
      quantity,
      payoutCurrency,
      fundsReceiver,
    ],
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}

export async function modifyListing(params: {
  listingId: bigint;
  newPricePerItem: bigint;
  newQuantity: bigint;
  payoutCurrency: Address;
  fundsReceiver: Address;
}) {
  const {
    listingId,
    newPricePerItem,
    newQuantity,
    payoutCurrency,
    fundsReceiver,
  } = params;
  const hash = await writeContract(config, {
    abi: ExchangeAbi,
    address: ADDRESSES.exchange,
    functionName: 'modifyListing',
    args: [
      listingId,
      newPricePerItem,
      newQuantity,
      payoutCurrency,
      fundsReceiver,
    ],
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}

export async function cancelListing(listingId: bigint) {
  const hash = await writeContract(config, {
    abi: ExchangeAbi,
    address: ADDRESSES.exchange,
    functionName: 'cancelListing',
    args: [listingId],
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}
