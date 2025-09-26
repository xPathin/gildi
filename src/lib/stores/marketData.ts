import { readable, writable, get, type Readable } from 'svelte/store';
import { publicClient } from '$lib/wagmi/config';
import {
  ADDRESSES,
  OrderBookAbi,
  ShareTokenAbi,
  ExchangeAbi,
} from '$lib/contracts/addresses';

export type MarketSnapshot = {
  tokenId: bigint;
  floorPriceCents?: bigint;
  totalSupply?: bigint;
  listedAvailable?: bigint;
  marketCapCents?: bigint;
  loading: boolean;
  error?: string;
};

const store = writable<Record<string, MarketSnapshot>>({});

const inflight = new Map<string, Promise<void>>();
const unwatchers = new Map<string, () => void>();

function key(tokenId: bigint) {
  return tokenId.toString();
}

async function loadToken(
  tokenId: bigint,
  tokenisedSharesPercentageBps?: bigint
) {
  const k = key(tokenId);
  const current = get(store)[k];
  store.update((s) => ({
    ...s,
    [k]: { ...(current || { tokenId }), loading: true, error: undefined },
  }));
  try {
    const [orderedResult, total, listed] = await Promise.all([
      publicClient.readContract({
        abi: OrderBookAbi as any,
        address: ADDRESSES.orderBook,
        functionName: 'getOrderedListings',
        args: [tokenId, 0n, 1n],
      }) as unknown as Promise<[any[], bigint]>,
      publicClient.readContract({
        abi: ShareTokenAbi as any,
        address: ADDRESSES.shareToken,
        functionName: 'totalSupply',
        args: [tokenId],
      }) as unknown as Promise<bigint>,
      publicClient.readContract({
        abi: OrderBookAbi as any,
        address: ADDRESSES.orderBook,
        functionName: 'listedQuantities',
        args: [tokenId],
      }) as unknown as Promise<bigint>,
    ]);
    const [orderedListings] = orderedResult as [any[], bigint];
    const floorPriceCents = orderedListings?.[0]?.pricePerItem as
      | bigint
      | undefined;
    const totalSupply = total as bigint;
    const listedAvailable = listed as bigint;
    let marketCapCents: bigint | undefined;
    if (
      floorPriceCents != null &&
      totalSupply != null &&
      tokenisedSharesPercentageBps &&
      tokenisedSharesPercentageBps > 0n
    ) {
      marketCapCents =
        (floorPriceCents * totalSupply * 10000n) / tokenisedSharesPercentageBps;
    }
    store.update((s) => ({
      ...s,
      [k]: {
        tokenId,
        floorPriceCents,
        totalSupply,
        listedAvailable,
        marketCapCents,
        loading: false,
      },
    }));
  } catch (e: any) {
    store.update((s) => ({
      ...s,
      [k]: {
        ...(s[k] || { tokenId }),
        loading: false,
        error: e?.message || 'Failed to load',
      },
    }));
  } finally {
    inflight.delete(k);
  }
}

function ensureLoaded(tokenId: bigint, tokenisedSharesPercentageBps?: bigint) {
  const k = key(tokenId);
  if (!inflight.has(k)) {
    const p = loadToken(tokenId, tokenisedSharesPercentageBps);
    inflight.set(k, p);
  }
}

function watchToken(tokenId: bigint, tokenisedSharesPercentageBps?: bigint) {
  const k = key(tokenId);
  if (unwatchers.has(k)) return; // already watching
  // Debounced refresh
  let t: ReturnType<typeof setTimeout> | undefined;
  const schedule = () => {
    if (t) clearTimeout(t);
    t = setTimeout(
      () => ensureLoaded(tokenId, tokenisedSharesPercentageBps),
      400
    );
  };
  const unwatchOB = publicClient.watchContractEvent({
    address: ADDRESSES.orderBook as any,
    abi: OrderBookAbi as any,
    eventName: 'Listed',
    onLogs: (logs: any[]) => {
      for (const log of logs) {
        const args: any = (log as any).args || {};
        if (args.releaseId != null && BigInt(args.releaseId) !== tokenId)
          continue;
        schedule();
      }
    },
  });
  const unwatchOB2 = publicClient.watchContractEvent({
    address: ADDRESSES.orderBook as any,
    abi: OrderBookAbi as any,
    eventName: 'Modified',
    onLogs: (logs: any[]) => {
      for (const log of logs) {
        const args: any = (log as any).args || {};
        if (args.releaseId != null && BigInt(args.releaseId) !== tokenId)
          continue;
        schedule();
      }
    },
  });
  const unwatchOB3 = publicClient.watchContractEvent({
    address: ADDRESSES.orderBook as any,
    abi: OrderBookAbi as any,
    eventName: 'Unlisted',
    onLogs: (logs: any[]) => {
      for (const log of logs) {
        const args: any = (log as any).args || {};
        if (args.releaseId != null && BigInt(args.releaseId) !== tokenId)
          continue;
        schedule();
      }
    },
  });
  const unwatchEx = publicClient.watchContractEvent({
    address: ADDRESSES.exchange as any,
    abi: ExchangeAbi as any,
    eventName: 'Purchased',
    onLogs: (logs: any[]) => {
      for (const log of logs) {
        const args: any = (log as any).args || {};
        if (args.releaseId != null && BigInt(args.releaseId) !== tokenId)
          continue;
        schedule();
      }
    },
  });
  unwatchers.set(k, () => {
    try {
      unwatchOB();
    } catch {}
    try {
      unwatchOB2();
    } catch {}
    try {
      unwatchOB3();
    } catch {}
    try {
      unwatchEx();
    } catch {}
  });
}

export function marketDataFor(
  tokenId: bigint,
  tokenisedSharesPercentageBps?: bigint
): Readable<MarketSnapshot> {
  ensureLoaded(tokenId, tokenisedSharesPercentageBps);
  watchToken(tokenId, tokenisedSharesPercentageBps);
  return readable<MarketSnapshot>({ tokenId, loading: true }, (set) => {
    const unsub = store.subscribe((all) => {
      const snap = all[key(tokenId)] || { tokenId, loading: true };
      set(snap);
    });
    return () => {
      unsub();
      // keep watcher to keep global cache hot; we can add reference counting later if desired
    };
  });
}
