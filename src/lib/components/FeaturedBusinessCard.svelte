<script lang="ts">
  import Button from './Button.svelte';
  import type { Readable } from 'svelte/store';
  import { marketDataFor, type MarketSnapshot } from '$lib/stores/marketData';

  export let business: any; // receives object from data store

  // Subscribe to global market data for this business
  let mdStore: Readable<MarketSnapshot> | undefined;
  $: mdStore = business?.tokenId
    ? marketDataFor(
        business.tokenId as bigint,
        business.tokenisedSharesPercentageBps as bigint
      )
    : undefined;

  function formatCurrency(amount?: number) {
    if (amount == null || Number.isNaN(amount)) return '—';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  }

  // Strict 2-decimal currency for per-share price
  function formatPrice(amount?: number) {
    if (amount == null || Number.isNaN(amount)) return '—';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  }
</script>

<div
  class="bg-white rounded-xl border border-gray-200 shadow-sm hover:shadow-md transition-shadow p-6"
>
  <!-- Header -->
  <div class="flex items-start justify-between mb-4">
    <div class="flex items-center space-x-3">
      <div
        class="w-12 h-12 bg-orange-50 rounded-xl flex items-center justify-center text-2xl"
      >
        {business.logo}
      </div>
      <div>
        <h3 class="font-semibold text-gray-900">{business.name}</h3>
        <p class="text-sm text-gray-500">{business.industry}</p>
      </div>
    </div>
    <div class="text-right">
      <div class="text-lg font-bold text-gray-900">
        {$mdStore?.floorPriceCents != null
          ? formatPrice(Number($mdStore.floorPriceCents) / 100)
          : '—'}
      </div>
      <div class="text-sm text-green-600">
        {business.keyMetrics.revenueGrowth}
      </div>
    </div>
  </div>

  <!-- Description -->
  <p class="text-gray-600 text-sm mb-4 line-clamp-2">
    {business.description.slice(0, 100)}...
  </p>

  <!-- Footer -->
  <div class="flex justify-end">
    <Button variant="primary" size="sm" href={'/business/' + business.id}>
      Invest Now
    </Button>
  </div>
</div>

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>
