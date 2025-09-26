<script lang="ts">
  import { browser } from '$app/environment';
  import { businesses } from '$lib/data/businesses';
  import Button from '$lib/components/Button.svelte';
  import { getOrderedListingsForRelease } from '$lib/contracts/exchange';

  type Section = {
    releaseId: bigint;
    business: (typeof businesses)[number];
    listings: Array<{
      id: bigint;
      releaseId: bigint;
      seller: `0x${string}`;
      pricePerItem: bigint; // USD cents
      quantity: bigint;
      fundsReceiver: `0x${string}`;
    }>;
    cursor: bigint;
    loading: boolean;
    error?: string;
  };

  function formatUsdCents(value: bigint) {
    return `$${(Number(value) / 100).toFixed(2)}`;
  }
  function shortAddress(addr: string) {
    return addr ? `${addr.slice(0, 6)}…${addr.slice(-4)}` : '';
  }

  // Initialize sections for each tokenized business
  let sections: Section[] = businesses
    .filter((b) => b.tokenId != null)
    .map((b) => ({
      releaseId: b.tokenId as bigint,
      business: b,
      listings: [],
      cursor: 0n,
      loading: false,
      error: undefined,
    }));

  async function loadInitial(section: Section) {
    if (!browser) return;
    if (section.loading) return;
    section.loading = true;
    section.error = undefined;
    try {
      const { listings, cursor } = await getOrderedListingsForRelease(
        section.releaseId,
        0n,
        25n
      );
      section.listings = listings;
      section.cursor = cursor;
    } catch (e) {
      section.error = e instanceof Error ? e.message : 'Failed to load listings';
    } finally {
      section.loading = false;
    }
  }

  async function loadMore(section: Section) {
    if (!browser) return;
    if (section.loading) return;
    section.loading = true;
    section.error = undefined;
    try {
      const { listings, cursor } = await getOrderedListingsForRelease(
        section.releaseId,
        section.cursor,
        25n
      );
      section.listings = [...section.listings, ...listings];
      section.cursor = cursor;
    } catch (e) {
      section.error = e instanceof Error ? e.message : 'Failed to load more listings';
    } finally {
      section.loading = false;
    }
  }

  // Auto-load on page init
  $: if (browser) {
    sections.forEach((s) => {
      if (s.listings.length === 0 && !s.loading) loadInitial(s);
    });
  }
</script>

<svelte:head>
  <title>Marketplace Listings - Gildi</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Header -->
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">Marketplace Listings</h1>
    <p class="text-gray-600">Browse all available listings by company</p>
  </div>

  {#if sections.length === 0}
    <div class="rounded-xl border border-gray-200 bg-white p-6 text-center text-gray-600">No tokenized businesses available.</div>
  {:else}
    {#each sections as s (String(s.releaseId))}
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden mb-8">
        <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
          <div class="flex items-center">
            <div class="w-10 h-10 bg-orange-50 rounded-lg flex items-center justify-center text-lg mr-3">{s.business.logo}</div>
            <div>
              <div class="text-lg font-semibold text-gray-900">{s.business.name}</div>
              <div class="text-sm text-gray-500">{s.business.industry}</div>
            </div>
          </div>
          <div>
            <Button variant="outline" href={`/business/${s.business.id}`}>View</Button>
          </div>
        </div>

        {#if s.error}
          <div class="px-6 py-3 text-sm text-red-600 bg-red-50">{s.error}</div>
        {/if}

        {#if s.listings.length === 0 && !s.loading}
          <div class="p-6 text-center text-gray-600">No active listings</div>
        {:else}
          <!-- Desktop Table -->
          <div class="hidden md:block overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Price</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Quantity</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Seller</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each s.listings as l (String(l.id))}
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{formatUsdCents(l.pricePerItem)}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{String(l.quantity)}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{shortAddress(l.seller)}</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <div class="flex space-x-2">
                        <Button variant="outline" size="sm" href={`/business/${s.business.id}`}>View</Button>
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
            {#each s.listings as l (String(l.id))}
              <div class="p-6 border-b border-gray-200 last:border-b-0">
                <div class="flex items-center justify-between mb-4">
                  <div>
                    <div class="font-medium text-gray-900">{formatUsdCents(l.pricePerItem)}</div>
                    <div class="text-sm text-gray-500">{String(l.quantity)} shares • Seller {shortAddress(l.seller)}</div>
                  </div>
                  <div class="text-right">
                    <Button variant="outline" size="sm" href={`/business/${s.business.id}`}>View</Button>
                  </div>
                </div>
                <div class="flex space-x-2">
                  <Button variant="primary" size="sm" class="flex-1" disabled>Buy</Button>
                </div>
              </div>
            {/each}
          </div>
        {/if}

        <div class="px-6 py-4">
          <Button variant="secondary" on:click={() => loadMore(s)} disabled={s.loading}>
            {s.loading ? 'Loading…' : 'Load more'}
          </Button>
        </div>
      </div>
    {/each}
  {/if}
</div>
