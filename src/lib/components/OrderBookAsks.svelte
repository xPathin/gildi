<script lang="ts">
  import { browser } from '$app/environment';
  import Button from '$lib/components/Button.svelte';
  import { getOrderedListingsForRelease } from '$lib/contracts/exchange';
  import type { Address } from 'viem';

  export let releaseId: bigint;
  export let pageSize: bigint = 25n;

  type Ask = {
    id: bigint;
    releaseId: bigint;
    seller: Address;
    pricePerItem: bigint; // USD cents
    quantity: bigint;
    fundsReceiver: Address;
  };

  let asks: Ask[] = [];
  let cursor: bigint = 0n;
  let loading = false;
  let errorMsg: string | undefined;

  function formatUsdCents(value: bigint) {
    return `$${(Number(value) / 100).toFixed(2)}`;
  }
  function shortAddress(addr: string) {
    return addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : '';
  }

  async function loadInitial() {
    if (!browser) return;
    if (loading) return;
    loading = true;
    errorMsg = undefined;
    try {
      const { listings, cursor: next } = await getOrderedListingsForRelease(
        releaseId,
        0n,
        pageSize
      );
      asks = listings;
      cursor = next;
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Failed to load order book';
    } finally {
      loading = false;
    }
  }

  async function loadMore() {
    if (!browser) return;
    if (loading) return;
    loading = true;
    errorMsg = undefined;
    try {
      const { listings, cursor: next } = await getOrderedListingsForRelease(
        releaseId,
        cursor,
        pageSize
      );
      asks = [...asks, ...listings];
      cursor = next;
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Failed to load more asks';
    } finally {
      loading = false;
    }
  }

  $: if (browser && asks.length === 0 && !loading && releaseId != null) {
    loadInitial();
  }
</script>

<div class="bg-white rounded-xl border border-gray-200 p-8">
  <h2 class="text-2xl font-bold text-gray-900 mb-4">Available Listings</h2>
  {#if loading}
    <span class="text-sm text-gray-500">Loading…</span>
  {/if}

  {#if errorMsg}
    <div class="px-6 py-3 text-sm text-red-600 bg-red-50">{errorMsg}</div>
  {/if}

  {#if asks.length === 0 && !loading}
    <div class="p-6 text-center text-gray-600">No active listings</div>
  {:else}
    <!-- Desktop Table -->
    <div class="hidden md:block overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >Price</th
            >
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >Quantity</th
            >
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >Seller</th
            >
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >Actions</th
            >
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each asks as a (String(a.id))}
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                >{formatUsdCents(a.pricePerItem)}</td
              >
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                >{String(a.quantity)}</td
              >
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                >{shortAddress(a.seller)}</td
              >
              <td class="px-6 py-4 whitespace-nowrap text-sm">
                <div class="flex space-x-2">
                  <Button variant="primary" size="sm" disabled>Buy</Button>
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards -->
    <div class="md:hidden">
      {#each asks as a (String(a.id))}
        <div class="p-6 border-b border-gray-200 last:border-b-0">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-medium text-gray-900">
                {formatUsdCents(a.pricePerItem)}
              </div>
              <div class="text-sm text-gray-500">
                {String(a.quantity)} shares • Seller {shortAddress(a.seller)}
              </div>
            </div>
          </div>
          <div class="flex space-x-2">
            <Button variant="primary" size="sm" class="flex-1" disabled
              >Buy</Button
            >
          </div>
        </div>
      {/each}
    </div>
  {/if}

  <div class="py-4">
    <Button variant="primary" on:click={loadMore} disabled={loading}>
      {loading ? 'Loading…' : 'Load more'}
    </Button>
  </div>
</div>
