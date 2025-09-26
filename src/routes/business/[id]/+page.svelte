<script lang="ts">
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { businesses } from '$lib/data/businesses';
  import Button from '$lib/components/Button.svelte';
  import SellListingModal from '$lib/components/SellListingModal.svelte';
  import OrderBookAsks from '$lib/components/OrderBookAsks.svelte';
  import BuyModal from '$lib/components/BuyModal.svelte';
  import {
    getFloorPrice,
    getTotalShareSupply,
    getListedQuantities,
  } from '$lib/contracts/exchange';

  let showBuyModal = false;
  let showSellModal = false;
  let investmentAmount = 1000;
  let shareQuantity = 1;
  let buyPrefillQty: bigint | undefined;

  $: business = businesses.find((b) => b.id === $page.params.id);

  // On-chain derived state
  let floorPriceCents: bigint | undefined;
  let onchainTotalShares: bigint | undefined;
  let listedAvailable: bigint | undefined;
  let marketCapCents: bigint | undefined;

  function effectivePricePerShare(): number | undefined {
    if (floorPriceCents != null) return Number(floorPriceCents) / 100;
    return undefined;
  }

  function formatCurrency(amount?: number) {
    if (amount == null || Number.isNaN(amount)) return '—';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  }

  function formatNumber(num?: number) {
    if (num == null || Number.isNaN(num)) return '—';
    return new Intl.NumberFormat('en-US').format(num);
  }

  function handleInvestmentChange() {
    if (business) {
      const p = effectivePricePerShare();
      if (p && p > 0) shareQuantity = Math.floor(investmentAmount / p);
    }
  }

  function handleShareQuantityChange() {
    if (business) {
      const p = effectivePricePerShare();
      if (p && p > 0) investmentAmount = shareQuantity * p;
    }
  }

  async function refetchOnchain() {
    if (!business?.tokenId) return;
    const tokenId = business.tokenId;
    try {
      const [fp, total, listed] = await Promise.all([
        getFloorPrice(tokenId),
        getTotalShareSupply(tokenId),
        getListedQuantities(tokenId),
      ]);
      floorPriceCents = fp;
      onchainTotalShares = total;
      listedAvailable = listed;

      // Market cap: (floorPriceCents * totalShares) extrapolated to 100%
      if (
        floorPriceCents != null &&
        onchainTotalShares != null &&
        business.tokenisedSharesPercentageBps
      ) {
        const tokenizedValCents = floorPriceCents * onchainTotalShares;
        const bps = business.tokenisedSharesPercentageBps; // bigint bps
        if (bps > 0n) {
          marketCapCents = (tokenizedValCents * 10000n) / bps;
        }
      }
    } catch (e) {
      // keep existing values on failure
      console.error('refetchOnchain error', e);
    }
  }

  onMount(() => {
    refetchOnchain();
  });
</script>

<svelte:head>
  <title>{business?.name || 'Business'} - Gildi</title>
</svelte:head>

{#if !business}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
    <h1 class="text-2xl font-bold text-gray-900 mb-4">Business Not Found</h1>
    <p class="text-gray-600 mb-8">
      The business you're looking for doesn't exist.
    </p>
    <Button href="/">Back to Marketplace</Button>
  </div>
{:else}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Breadcrumb -->
    <nav class="mb-8">
      <ol class="flex items-center space-x-2 text-sm text-gray-500">
        <li><a href="/" class="hover:text-gray-700">Marketplace</a></li>
        <li>/</li>
        <li class="text-gray-900">{business.name}</li>
      </ol>
    </nav>

    <!-- Header -->
    <div class="bg-white rounded-xl border border-gray-200 p-8 mb-8">
      <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between">
        <div class="flex items-start space-x-6 mb-6 lg:mb-0">
          <div
            class="w-20 h-20 bg-orange-50 rounded-xl flex items-center justify-center text-4xl"
          >
            {business.logo}
          </div>
          <div>
            <h1 class="text-3xl font-bold text-gray-900 mb-2">
              {business.name}
            </h1>
            <p class="text-lg text-gray-600 mb-2">{business.industry}</p>
            <div class="flex items-center space-x-4 text-sm text-gray-500">
              <span>📍 {business.location}</span>
              <span>👥 {business.employees} employees</span>
              <span>📅 Founded {business.founded}</span>
            </div>
          </div>
        </div>

        <div class="text-right">
          <div class="text-4xl font-bold text-gray-900 mb-1">
            {floorPriceCents != null
              ? formatCurrency(Number(floorPriceCents) / 100)
              : '—'}
          </div>
          <div class="text-gray-500">per share</div>
          <div class="mt-4 space-y-2">
            <Button
              variant="primary"
              size="lg"
              on:click={() => (showBuyModal = true)}
              disabled={!business?.tokenId}
            >
              Buy Shares
            </Button>
            <Button
              variant="outline"
              size="lg"
              on:click={() => (showSellModal = true)}
              disabled={!business?.tokenId}
            >
              Sell Shares
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Main Content -->
      <div class="lg:col-span-2 space-y-8">
        {#if business?.tokenId != null}
          <OrderBookAsks
            releaseId={business.tokenId}
            on:buy={(e) => {
              buyPrefillQty = e.detail.quantity;
              showBuyModal = true;
            }}
            on:updated={() => {
              refetchOnchain();
            }}
          />
        {/if}
        <!-- Description -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">
            About {business.name}
          </h2>
          <p class="text-gray-600 leading-relaxed">{business.description}</p>
        </div>

        <!-- Images -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Company Images</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            {#each business.images as image}
              <img
                src={image}
                alt={business.name}
                class="w-full h-48 object-cover rounded-lg"
              />
            {/each}
          </div>
        </div>

        <!-- Key Metrics -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">
            Financial Metrics
          </h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Revenue Growth
              </div>
              <div class="text-2xl font-bold text-green-600">
                {business.keyMetrics.revenueGrowth}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Profit Margin
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.profitMargin}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Debt to Equity
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.debtToEquity}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Return on Equity
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.returnOnEquity}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="space-y-6">
        <!-- Investment Summary -->
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">
            Investment Summary
          </h3>
          <div class="space-y-4">
            <div class="flex justify-between">
              <span class="text-gray-600">Market Cap</span>
              <span class="font-semibold">
                {marketCapCents != null
                  ? formatCurrency(Number(marketCapCents) / 100)
                  : '—'}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Annual Revenue</span>
              <span class="font-semibold"
                >{formatCurrency(business.yearlyRevenue)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Total Shares</span>
              <span class="font-semibold">
                {onchainTotalShares != null
                  ? formatNumber(Number(onchainTotalShares))
                  : '—'}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Available Shares</span>
              <span class="font-semibold">
                {listedAvailable != null
                  ? formatNumber(Number(listedAvailable))
                  : '—'}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Risk Level</span>
              <span
                class="font-semibold"
                class:text-green-600={business.riskLevel === 'Low'}
                class:text-yellow-600={business.riskLevel === 'Medium'}
                class:text-red-600={business.riskLevel === 'High'}
              >
                {business.riskLevel}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  {#if business?.tokenId != null}
    <BuyModal
      bind:open={showBuyModal}
      releaseId={business.tokenId}
      prefillQuantity={buyPrefillQty}
      on:purchased={() => {
        refetchOnchain();
      }}
    />
  {/if}
  {#if business?.tokenId != null}
    <SellListingModal
      bind:open={showSellModal}
      releaseId={business.tokenId}
      on:created={() => {
        refetchOnchain();
      }}
    />
  {/if}
{/if}
