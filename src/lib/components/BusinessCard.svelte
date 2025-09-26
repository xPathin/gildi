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

<div class="card p-6 hover:shadow-lg transition-all duration-300 group">
  <!-- Header -->
  <div class="flex items-start justify-between mb-4">
    <div class="flex items-center space-x-3">
      <div
        class="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center text-2xl"
      >
        {business.logo}
      </div>
      <div>
        <h3
          class="font-semibold text-gray-900 group-hover:text-primary-600 transition-colors"
        >
          {business.name}
        </h3>
        <p class="text-sm text-gray-500">{business.industry}</p>
      </div>
    </div>
    <div class="text-right">
      <div class="text-lg font-bold text-gray-900">
        {$mdStore?.floorPriceCents != null
          ? formatPrice(Number($mdStore.floorPriceCents) / 100)
          : '—'}
      </div>
      <div class="text-xs text-gray-500">per share</div>
    </div>
  </div>

  <!-- Key Metrics -->
  <div class="grid grid-cols-2 gap-4 mb-4">
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Market Cap
      </div>
      <div class="font-semibold text-gray-900">
        {$mdStore?.marketCapCents != null
          ? formatCurrency(Number($mdStore.marketCapCents) / 100)
          : '—'}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">Revenue</div>
      <div class="font-semibold text-gray-900">
        {formatCurrency(business.yearlyRevenue)}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Revenue Growth
      </div>
      <div class="font-semibold text-green-600">
        {business.keyMetrics.revenueGrowth}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Risk Level
      </div>
      <div
        class="font-semibold"
        class:text-green-600={business.riskLevel === 'Low'}
        class:text-yellow-600={business.riskLevel === 'Medium'}
        class:text-red-600={business.riskLevel === 'High'}
      >
        {business.riskLevel}
      </div>
    </div>
  </div>

  <!-- Actions -->
  <div class="flex space-x-2">
    <Button
      variant="primary"
      size="sm"
      href={'/business/' + business.id}
      class="flex-1"
    >
      View Details
    </Button>
    <Button variant="outline" size="sm" class="px-3">
      <svg
        class="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
        />
      </svg>
    </Button>
  </div>
</div>
